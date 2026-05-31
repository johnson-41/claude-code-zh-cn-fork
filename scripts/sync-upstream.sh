#!/usr/bin/env bash
# sync-upstream.sh - 从原版仓库 (taekchef/claude-code-zh-cn) 同步翻译和 patch 引擎
# 用法: bash scripts/sync-upstream.sh [--dry-run]
#
# 同步的文件:
#   - cli-translations.json      (翻译条目)
#   - patch-cli.js               (patch 引擎)
#   - plugin/support-window.json (版本支持窗口)
#   - bun-binary-io.js           (二进制 I/O)
#   - verbs/zh-CN.json           (spinner 动词)
#   - tips/zh-CN.json            (spinner 提示)
#
# 环境变量:
#   UPSTREAM_REPO  - 上游仓库 (默认: taekchef/claude-code-zh-cn)
#   UPSTREAM_REF   - 上游 ref (默认: main)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
UPSTREAM_REPO="${UPSTREAM_REPO:-taekchef/claude-code-zh-cn}"
UPSTREAM_REF="${UPSTREAM_REF:-main}"
DRY_RUN=false
TMP_DIR=""

if [ "${1:-}" = "--dry-run" ]; then
    DRY_RUN=true
fi

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

cleanup() {
    if [ -n "${TMP_DIR:-}" ] && [ -d "$TMP_DIR" ]; then
        rm -rf "$TMP_DIR"
    fi
}
trap cleanup EXIT

echo -e "${BLUE}=== 同步上游翻译和 patch 引擎 ===${NC}"
echo "上游仓库: ${UPSTREAM_REPO} (${UPSTREAM_REF})"
echo ""

# 需要同步的文件列表
SYNC_FILES=(
    "cli-translations.json"
    "patch-cli.js"
    "bun-binary-io.js"
    "plugin/support-window.json"
    "verbs/zh-CN.json"
    "tips/zh-CN.json"
)

# 克隆上游仓库
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/cczh-sync-upstream.XXXXXX")"
echo -e "${BLUE}正在克隆上游仓库...${NC}"

if ! git clone --depth 1 --branch "$UPSTREAM_REF" "https://github.com/${UPSTREAM_REPO}.git" "$TMP_DIR/upstream" 2>/dev/null; then
    echo -e "${RED}错误：无法克隆上游仓库 ${UPSTREAM_REPO}${NC}"
    echo "请检查网络连接或仓库地址"
    exit 1
fi

echo -e "${GREEN}克隆完成${NC}"
echo ""

# 检查差异并同步
changed=0
skipped=0
errors=0

for file in "${SYNC_FILES[@]}"; do
    src="$TMP_DIR/upstream/$file"
    dst="$REPO_ROOT/$file"

    if [ ! -f "$src" ]; then
        echo -e "${YELLOW}  跳过 $file（上游不存在）${NC}"
        skipped=$((skipped + 1))
        continue
    fi

    # 检查是否有变化
    if [ -f "$dst" ] && diff -q "$src" "$dst" >/dev/null 2>&1; then
        echo -e "  $file — 无变化"
        skipped=$((skipped + 1))
        continue
    fi

    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}  $file — 有变化（dry-run，未复制）${NC}"
        # 显示简要 diff 统计
        if [ -f "$dst" ]; then
            diff --stat "$dst" "$src" 2>/dev/null || true
        else
            echo "    新增文件: $(wc -l < "$src") 行"
        fi
        changed=$((changed + 1))
        continue
    fi

    # 确保目标目录存在
    mkdir -p "$(dirname "$dst")"

    if cp "$src" "$dst"; then
        echo -e "${GREEN}  $file — 已更新${NC}"
        changed=$((changed + 1))
    else
        echo -e "${RED}  $file — 复制失败${NC}"
        errors=$((errors + 1))
    fi
done

echo ""

# 同步 plugin/ 镜像
if [ "$changed" -gt 0 ] && [ "$DRY_RUN" = false ]; then
    echo -e "${BLUE}正在同步 plugin/ 镜像...${NC}"
    bash "$SCRIPT_DIR/sync-payload.sh"
    echo ""
fi

# 汇总
echo -e "${BLUE}=== 同步完成 ===${NC}"
echo "  更新: ${changed}"
echo "  跳过: ${skipped}"
if [ "$errors" -gt 0 ]; then
    echo -e "  ${RED}失败: ${errors}${NC}"
fi

if [ "$DRY_RUN" = true ]; then
    echo ""
    echo -e "${YELLOW}这是 dry-run 模式，未实际修改文件。去掉 --dry-run 参数执行实际同步。${NC}"
fi

# 输出翻译条目数（如果有 node）
if [ "$changed" -gt 0 ] && [ "$DRY_RUN" = false ] && command -v node &>/dev/null; then
    trans_count=$(node -e "const d=JSON.parse(require('fs').readFileSync('$REPO_ROOT/cli-translations.json','utf8')); process.stdout.write(String(d.length))" 2>/dev/null || echo "?")
    echo ""
    echo -e "当前翻译条目数: ${GREEN}${trans_count}${NC}"
fi
