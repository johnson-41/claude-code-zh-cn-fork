#!/usr/bin/env bash
# common.sh - 共享函数库
# 被 install.sh 和 hooks/session-start 共同引用
# 前置条件：调用方需设置 $PLUGIN_ROOT 指向 plugin/ 目录

native_binary_version() {
    local binary_path="$1"
    local version output temp_home

    version="$(node "$PLUGIN_ROOT/bun-binary-io.js" version "$binary_path" 2>/dev/null || true)"
    if [ -n "${version:-}" ]; then
        printf '%s' "$version"
        return
    fi

    temp_home="$(mktemp -d "${TMPDIR:-/tmp}/cczh-version-home.XXXXXX" 2>/dev/null || true)"
    if [ -n "${temp_home:-}" ]; then
        output="$(HOME="$temp_home" XDG_CONFIG_HOME="$temp_home/.config" XDG_CACHE_HOME="$temp_home/.cache" XDG_DATA_HOME="$temp_home/.local/share" "$binary_path" --version 2>/dev/null || true)"
        rm -rf "$temp_home" 2>/dev/null || true
    else
        output="$("$binary_path" --version 2>/dev/null || true)"
    fi

    printf '%s' "$output" | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true
}

is_supported_native_version() {
    local version="$1"
    local support_file="$PLUGIN_ROOT/support-window.json"

    if [ ! -f "$support_file" ]; then
        # 无配置文件时直接返回不支持
        return 1
    fi

    node - "$support_file" "$version" <<'NODE'
const fs = require("fs");
const file = process.argv[2];
const version = process.argv[3];
const data = JSON.parse(fs.readFileSync(file, "utf8"));
const versions = [
  ...(data.macosNativeOfficialInstallerExperimental?.versions || []),
  ...(data.macosNativeExperimental?.versions || []),
  ...(data.linuxNativeExperimental?.versions || []),
  ...(data.windowsNativeExperimental?.versions || []),
];
process.exit(versions.includes(version) ? 0 : 1);
NODE
}

native_binary_hash() {
    local binary_path="$1"
    node "$PLUGIN_ROOT/bun-binary-io.js" hash "$binary_path" 2>/dev/null || printf "unknown"
}

find_real_claude_binary() {
    if [ -n "${ZH_CN_REAL_CLAUDE:-}" ] && [ -x "${ZH_CN_REAL_CLAUDE:-}" ]; then
        printf "%s" "$ZH_CN_REAL_CLAUDE"
        return
    fi

    local filtered_path=""
    local path_entry
    local old_ifs="$IFS"
    IFS=':'
    for path_entry in ${PATH:-}; do
        if [ "${path_entry:-}" = "$LAUNCHER_BIN_DIR" ]; then
            continue
        fi
        if [ -z "$filtered_path" ]; then
            filtered_path="$path_entry"
        else
            filtered_path="${filtered_path}:$path_entry"
        fi
    done
    IFS="$old_ifs"

    PATH="$filtered_path" command -v claude 2>/dev/null || true
}
