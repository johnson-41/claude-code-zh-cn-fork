<div align="center">

# claude-code-zh-cn

**Claude Code 界面汉化插件**

让终端里的 AI 编程助手说中文

[![GitHub](https://img.shields.io/badge/GitHub-KongBai1145%2Fclaude--code--zh--cn-blue?logo=github)](https://github.com/KongBai1145/claude-code-zh-cn)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)
[![Version](https://img.shields.io/github/v/tag/KongBai1145/claude-code-zh-cn?label=Version&color=blue)](https://github.com/KongBai1145/claude-code-zh-cn/releases)

**一键安装 · 自动更新 · 安全卸载**

</div>

---

## 安装

### Windows

双击 `install.bat`，打开可视化安装器，按提示操作即可。

```
  1. 一键汉化
  2. 更新汉化
  3. 卸载所有汉化
  4. 打开备份文件夹
  5. 手动备份
```

### macOS / Linux

```bash
curl -fsSL https://raw.githubusercontent.com/KongBai1145/claude-code-zh-cn/main/quick-install.sh | bash
```

---

## 效果

| 安装前 | 安装后 |
|--------|--------|
| `Photosynthesizing...` | `光合作用中...` |
| `Thinking...` | `思考中...` |
| `Tip: Press Shift+Tab...` | `按 Shift+Tab 切换模式` |

187 个 spinner 动词，1742 条 UI 翻译，AI 默认中文回复。

---

## 支持范围

| 安装方式 | 支持 |
|----------|------|
| npm (`@anthropic-ai/claude-code`) | ✅ 完整支持 |
| macOS 官方安装器 (2.1.110-2.1.156) | ✅ experimental |
| Windows 官方安装器 (2.1.113-2.1.153) | ✅ experimental |
| Linux native (2.1.126) | ✅ experimental |

> node-lief 依赖会在安装时自动处理，无需手动安装。

---

## 更新与卸载

**更新**：插件每 6 小时自动检查上游翻译更新。也可手动运行安装器选择「更新汉化」。

**卸载**：运行安装器选择「卸载所有汉化」。卸载前会验证备份文件是否为英文原版，确保恢复安全。

---

## 诊断

安装后如有问题：

```bash
./doctor.sh
```

---

## 功能

- AI 默认中文回复
- 187 个趣味 spinner（`光合作用中`、`蹦迪中`、`七荤八素中`...）
- 1742 条 UI 翻译（菜单、提示、快捷键、slash 命令）
- Claude Code 更新后自动重新翻译
- Windows 可视化安装器
- 一键诊断工具
- 安全卸载（验证备份后再恢复）

---

## 技术原理

<details>
<summary>点击展开</summary>

四层中文化机制：

1. **设置注入** — `settings.json` 设置语言和 spinner
2. **Hook 系统** — 会话启动注入中文上下文
3. **插件系统** — 中文输出风格
4. **CLI Patch** — 直接翻译 UI 硬编码文字

Layer 1-3 不受 Claude Code 更新影响，Layer 4 自动重新翻译。

</details>

---

## FAQ

<details>
<summary>Claude Code 更新后会失效吗？</summary>

不会。插件自动检测版本变更并重新翻译。
</details>

<details>
<summary>会不会破坏原有功能？</summary>

不会。安装前自动备份，卸载时验证备份是否为英文原版后再恢复。
</details>

<details>
<summary>支持哪些系统？</summary>

macOS、Linux、Windows（PowerShell / WSL）。需要 Node.js。
</details>

---

## 贡献

- 翻译改进 → 编辑 `tips/zh-CN.json` 或 `verbs/zh-CN.json`
- Bug 反馈 → [提交 Issue](https://github.com/KongBai1145/claude-code-zh-cn/issues)

---

## 致谢

- 原项目：[taekchef/claude-code-zh-cn](https://github.com/taekchef/claude-code-zh-cn)
- UI 字符串提取自 [Claude Code](https://github.com/anthropics/claude-code)

---

## 许可证

[MIT](./LICENSE)
