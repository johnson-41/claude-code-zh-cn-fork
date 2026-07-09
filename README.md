<div align="center">

# claude-code-zh-cn

**Claude Code 界面汉化插件**

让终端里的 AI 编程助手说中文

[![GitHub](https://img.shields.io/badge/GitHub-KongBai1145%2Fclaude--code--zh--cn-blue?logo=github)](https://github.com/KongBai1145/claude-code-zh-cn)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)
[![Version](https://img.shields.io/github/v/tag/KongBai1145/claude-code-zh-cn?label=Version&color=blue)](https://github.com/KongBai1145/claude-code-zh-cn/releases)

**一键安装 · 自动更新 · 安全卸载 · Windows 可视化安装器**

</div>

---

## 安装

### Windows（推荐）

双击 `install.bat`，打开可视化安装器：

```
┌─────────────────────────────────────────┐
│  Claude Code 中文本地化                   │
├─────────────────────────────────────────┤
│  1. 一键汉化      安装插件 + 翻译 CLI 界面  │
│  2. 更新汉化      重新同步翻译和补丁         │
│  3. 卸载所有汉化   恢复英文原版              │
│  4. 打开备份文件夹                          │
│  5. 手动备份       打包为 zip               │
└─────────────────────────────────────────┘
```

也可以命令行安装：

```powershell
git clone https://github.com/KongBai1145/claude-code-zh-cn.git
cd claude-code-zh-cn
.\install.ps1
```

### macOS / Linux

```bash
curl -fsSL https://raw.githubusercontent.com/KongBai1145/claude-code-zh-cn/main/quick-install.sh | bash
```

安装脚本会自动检测系统和 Claude Code 版本，无需手动选择。

---

## 效果预览

| 安装前 | 安装后 |
|--------|--------|
| `Photosynthesizing...` | `光合作用中...` |
| `Thinking...` | `思考中...` |
| `Tip: Press Shift+Tab...` | `按 Shift+Tab 切换模式` |

187 个趣味 spinner 动词，41 条中文提示，1742 条 UI 翻译。**装完即用，重启 Claude Code 生效。**

---

## 支持范围

| 安装方式 | 支持情况 |
|----------|---------|
| `npm install -g @anthropic-ai/claude-code` | ✅ 完整支持 |
| macOS 官方安装器 (2.1.110 - 2.1.205) | ✅ experimental |
| Windows 官方安装器 (2.1.113 - 2.1.205) | ✅ experimental |
| Linux native (2.1.126) | ✅ experimental |
| 其他版本 | ⚠️ 设置和 Hook 生效，UI 翻译可能不完整 |

> node-lief 依赖会在安装时自动处理，无需手动安装。

---

## 更新

插件每 6 小时自动检查上游翻译更新并同步。**无需手动操作。**

禁用自动更新：设置环境变量 `ZH_CN_DISABLE_AUTO_UPDATE=1`

手动更新：

- **Windows**：双击 `install.bat` → 选择「更新汉化」
- **macOS / Linux**：`cd claude-code-zh-cn && git pull && ./install.sh`

---

## 卸载

- **Windows**：双击 `install.bat` → 选择「卸载所有汉化」
- **macOS / Linux**：`./uninstall.sh`

卸载流程：

1. 验证备份文件是否为英文原版（检查是否包含英文原文）
2. 备份干净 → 自动恢复
3. 备份也是汉化版 → 提示手动 `npm install -g` 恢复
4. 清除汉化设置、插件目录、launcher

---

## 诊断

安装后如有问题，运行诊断工具：

```bash
./doctor.sh
```

诊断内容包括：Node.js 版本、插件目录、settings.json、CLI Patch 状态、自动更新状态等。

---

## 特色功能

| 功能 | 说明 |
|------|------|
| **AI 中文回复** | 默认使用简体中文回复，技术术语保留英文 |
| **187 个趣味动词** | `光合作用中`、`七荤八素中`、`蹦迪中`、`搞事业中`... |
| **1742 条 UI 翻译** | 覆盖菜单、提示、快捷键、slash 命令、CLI 参数 |
| **自动修复** | Claude Code 更新后自动检测并重新翻译 |
| **自动更新** | 插件发布新版本后自动同步翻译 |
| **Windows GUI** | 可视化安装器，双击 `install.bat` 即用 |
| **诊断工具** | `doctor.sh` 一键检查安装状态 |
| **安全卸载** | 验证备份后再恢复，不破坏原有配置 |
| **手动备份** | 一键打包所有相关文件为 zip |

---

## 技术原理

<details>
<summary>点击展开</summary>

本插件通过四层机制实现中文化：

1. **设置注入** — 修改 `settings.json`，设置语言和 spinner
2. **Hook 系统** — 会话启动时注入中文上下文指令
3. **插件系统** — 提供中文输出风格
4. **CLI Patch** — 直接翻译 UI 硬编码文字（1742 条）

Layer 1-3 不受 Claude Code 更新影响，Layer 4 会自动重新翻译。

</details>

---

## FAQ

<details>
<summary>Claude Code 更新后会失效吗？</summary>

不会。插件会自动检测版本变更并重新翻译。也可手动点击「更新汉化」。
</details>

<details>
<summary>会不会破坏原有功能？</summary>

不会。安装前自动备份，卸载时验证备份是否为英文原版后再恢复。
</details>

<details>
<summary>支持哪些系统？</summary>

macOS、Linux、Windows（PowerShell 5.1+ / WSL）。需要 Node.js。
</details>

<details>
<summary>翻译条目会同步更新吗？</summary>

会。插件内置上游同步机制，CI 每周自动检查原项目翻译更新。
</details>

---

## 贡献

欢迎 PR！

- 翻译改进 → 编辑 `tips/zh-CN.json` 或 `verbs/zh-CN.json`
- Bug 反馈 → [提交 Issue](https://github.com/KongBai1145/claude-code-zh-cn/issues)

---

## 致谢

- 原项目 fork 自 [taekchef/claude-code-zh-cn](https://github.com/taekchef/claude-code-zh-cn)。**自 v2.5.0 起由本仓库独立维护**——重点支持 Claude Code 2.1.92+ 全版本，并扩展到 native experimental 通道（macOS / Windows 二进制包）
- UI 字符串提取自 [Claude Code](https://github.com/anthropics/claude-code)

---

## 许可证

[MIT](./LICENSE)

*本项目不是 Anthropic 官方产品。Claude Code 是 Anthropic Inc. 的商标。*
