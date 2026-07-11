#!/usr/bin/env bash
# patch-cli.sh - cli.js 硬编码文字中文 patch 入口
# 被 install.sh 和 session-start hook 调用
# 用法: patch-cli.sh <cli.js路径>
# 返回值: 成功 patch 的数量

set -euo pipefail

# 确保 UTF-8 locale，防止中文输出乱码（尤其是 Cloud / CI 环境）
export LC_ALL="${LC_ALL:-C.UTF-8}"
export LANG="${LANG:-C.UTF-8}"

CLI_FILE="${1:-}"

if [ -z "$CLI_FILE" ] || [ ! -f "$CLI_FILE" ]; then
    echo "0"
    exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

node "$SCRIPT_DIR/patch-cli.js" "$CLI_FILE" "$SCRIPT_DIR/cli-translations.json" 2>/dev/null
