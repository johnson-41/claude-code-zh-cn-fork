#!/usr/bin/env bash
# auto-repatch.sh - 自动 patch 检测和修复逻辑
# 检测 cli.js 版本变更，自动重 patch


# 确保 UTF-8 locale（Cloud 环境默认可能为 C/POSIX，中文输出会乱码）
export LC_ALL="${LC_ALL:-C.UTF-8}"
export LANG="${LANG:-en_US.UTF-8}"

# 前置条件：调用方需设置以下变量
# - PLUGIN_ROOT
# - MARKER_FILE
# - LAUNCHER_BIN_DIR

npm_cli_probe_residue() {
    node - "$1" <<'NODE'
const fs = require("fs");

const cliFile = process.argv[2];
const probes = [
  "Quick safety check",
  "This command requires approval",
  "Use /btw to ask a quick side question without interrupting Claude's current work",
];

try {
  const text = fs.readFileSync(cliFile, "utf8");
  const residue = probes.filter((probe) => text.includes(probe));
  if (residue.length > 0) {
    process.stdout.write(residue.join(" | "));
    process.exit(0);
  }
} catch {}

process.exit(1);
NODE
}

# 主逻辑：检测并执行自动 patch
# 返回值：通过 AUTO_PATCH_MSG 变量传递 patch 消息
check_and_repatch() {
    AUTO_PATCH_MSG=""

    # 检测安装类型
    local install_info=""
    local helper_available=false
    if [ -f "$PLUGIN_ROOT/bun-binary-io.js" ]; then
        install_info="$(node "$PLUGIN_ROOT/bun-binary-io.js" detect "$(find_real_claude_binary)" 2>/dev/null || true)"
        helper_available=true
    fi

    local install_kind="${install_info%%:*}"
    local install_target="${install_info#*:}"

    local cli_file=""
    local native_binary=""
    case "$install_kind" in
        npm)
            cli_file="$install_target"
            ;;
        native-bun)
            native_binary="$install_target"
            ;;
    esac

    # Fallback: 仅当 helper 文件不存在时走旧检测逻辑
    if [ "$helper_available" = false ] && [ -z "$cli_file" ] && [ -z "$native_binary" ]; then
        cli_file="$(dirname "$(which claude 2>/dev/null || true)")/../lib/node_modules/@anthropic-ai/claude-code/cli.js" 2>/dev/null || true
        if [ -z "$cli_file" ] || [ ! -f "$cli_file" ]; then
            cli_file="$(npm root -g 2>/dev/null)/@anthropic-ai/claude-code/cli.js" 2>/dev/null || true
        fi
        if [ -z "$cli_file" ] || [ ! -f "$cli_file" ]; then
            cli_file=""
        fi
    fi

    if [ -n "$native_binary" ]; then
        _repatch_native "$native_binary"
    elif [ -f "$cli_file" ]; then
        _repatch_npm "$cli_file"
    fi
}

_repatch_native() {
    local native_binary="$1"

    # 原生二进制：只对已验证的 macOS 官方安装器旧版本做 best-effort re-patch
    local current_version
    current_version=$(native_binary_version "$native_binary")

    if ! is_supported_native_version "$current_version"; then
        return
    fi

    local patch_revision current_hash current_marker patched_version
    patch_revision=$(compute_patch_revision "$PLUGIN_ROOT" 2>/dev/null || true)
    current_hash=$(native_binary_hash "$native_binary")
    current_marker="native|${current_version}|${current_hash:-unknown}"
    [ -n "${patch_revision:-}" ] && current_marker="native|${current_version}|${current_hash:-unknown}|${patch_revision}"

    patched_version=""
    [ -f "$MARKER_FILE" ] && patched_version=$(cat "$MARKER_FILE")

    if [ "$current_marker" = "$patched_version" ]; then
        return
    fi

    if ! node "$PLUGIN_ROOT/bun-binary-io.js" check-deps 2>/dev/null | grep -q "ok"; then
        return
    fi

    local tmp_js backup_path backup_version
    tmp_js="$(mktemp "${TMPDIR:-/tmp}/claude-zh-cn-repatch.XXXXXX.js")"
    backup_path="${native_binary}.zh-cn-backup"
    backup_version=""
    if [ -f "$backup_path" ]; then
        backup_version=$(native_binary_version "$backup_path")
    fi

    # 同版本时恢复 backup 保证干净基底；版本变化时刷新 backup 为当前版本
    if [ -f "$backup_path" ] && [ -n "${current_version:-}" ] && [ "${current_version:-}" = "${backup_version:-}" ]; then
        mv "$backup_path" "$native_binary" 2>/dev/null || true
    else
        cp "$native_binary" "$backup_path" 2>/dev/null || true
    fi

    if node "$PLUGIN_ROOT/bun-binary-io.js" extract "$native_binary" "$tmp_js" 2>/dev/null; then
        local patch_count
        patch_count=$("$PLUGIN_ROOT/patch-cli.sh" "$tmp_js" 2>/dev/null || echo "0")
        if [ "$patch_count" != "0" ]; then
            if node "$PLUGIN_ROOT/bun-binary-io.js" repack "$native_binary" "$tmp_js" 2>/dev/null; then
                local final_hash final_marker
                final_hash=$(native_binary_hash "$native_binary")
                final_marker="native|${current_version}|${final_hash:-unknown}"
                [ -n "${patch_revision:-}" ] && final_marker="native|${current_version}|${final_hash:-unknown}|${patch_revision}"
                echo "$final_marker" > "$MARKER_FILE"
                AUTO_PATCH_MSG="（已自动 patch ${patch_count} 处硬编码文字 — 官方安装器 native experimental）"
            fi
        fi
    fi
    rm -f "$tmp_js"
}

_repatch_npm() {
    local cli_file="$1"

    local current_version patch_revision current_marker patched_version
    current_version=$(head -6 "$cli_file" | grep -o '// Version: [^ ]*' | head -1 | sed 's/\/\/ Version: //')
    patch_revision=$(compute_patch_revision "$PLUGIN_ROOT" 2>/dev/null || true)
    current_marker="${current_version}"
    if [ -n "${patch_revision:-}" ]; then
        current_marker="${current_version}|${patch_revision}"
    fi

    patched_version=""
    [ -f "$MARKER_FILE" ] && patched_version=$(cat "$MARKER_FILE")

    local npm_probe_residue=""
    if npm_probe_residue="$(npm_cli_probe_residue "$cli_file")"; then
        :
    else
        npm_probe_residue=""
    fi

    if [ "$current_marker" = "$patched_version" ] && [ -z "$npm_probe_residue" ]; then
        return
    fi

    local patch_count
    patch_count=$("$PLUGIN_ROOT/patch-cli.sh" "$cli_file" 2>/dev/null || echo "0")

    if npm_probe_residue="$(npm_cli_probe_residue "$cli_file")"; then
        :
    else
        npm_probe_residue=""
    fi

    if [ "$patch_count" != "0" ] && [ -z "$npm_probe_residue" ]; then
        echo "$current_marker" > "$MARKER_FILE"
    fi

    if [ "$patch_count" != "0" ] && [ -z "$npm_probe_residue" ]; then
        AUTO_PATCH_MSG="（已自动 patch ${patch_count} 处硬编码文字）"
    fi
}
