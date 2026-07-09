# claude-code-zh-cn 升级到 Claude Code 2.1.202 — 2.1.205 — 设计文档

- 日期：2026-07-09
- 作者：九天 + 全能合伙人
- 关联项目：`D:\Users\test123\Downloads\claude-code-zh-cn`
- 目标版本：Claude Code 2.1.202 / 2.1.203 / 2.1.204 / 2.1.205
- 插件目标发布版本：2.6.0

---

## 1. 背景与目标

### 1.1 为什么升级

Anthropic 已经在 npm 上发布了 Claude Code 的 4 个新版本：

- 2.1.202
- 2.1.203
- 2.1.204
- 2.1.205（当前上游最新）

本项目（`claude-code-zh-cn`，2.5.0）的"native binary experimental"支持通道目前覆盖到：

- macOS arm64：2.1.113 — 2.1.156
- Windows x64：2.1.113 — 2.1.201

也就是说，**用户如果装的是 2.1.202 及以上**：

- L1（设置注入）/ L2（Hook）/ L3（输出风格）三层还能用
- L4（CLI 硬编码英文翻译）会被 **support-boundary-guard 拦截**——`scripts/check-support-boundary.js` 看到 install 脚本里出现未列入窗口的版本就会拒绝 patch

效果是：**用户升了 2.1.205，能用中文 spinner 和中文输出风格，但终端里硬编码的英文菜单/提示会冒出来**。

### 1.2 目标

把 native experimental 支持通道扩到 2.1.205，让用户装 2.1.202-2.1.205 后**至少能跑通完整的 L1-L4**，翻译质量靠用户和后续迭代补。

### 1.3 明确不做的事

- **不重写 patch-cli.js**：翻译引擎本身不动，避免引入新 bug
- **不补翻译条目**：cli-translations.json 也不动——我没真装 2.1.202-205，**没有证据**知道缺哪条
- **不写新的 CI workflow**：现有 GitHub Actions 已覆盖
- **不写新预检脚本**：避免过度设计
- **不真装新版本到 Claude Code 主环境**：会污染自己。验证只跑在 `tests/` 测试矩阵上
- **不解决 2.1.201 之前的翻译残问题**：跟本次目标无关
- **不补 2.1.157-2.1.201 这段已发布但未纳入 native 窗口的版本**：用户决策是"仅升级到最近 2-3 个小版本"（202-205），所以这段保持原状（Windows 已含 201，macOS 没含；本次不动）

---

## 2. 现状勘察

### 2.1 项目结构（与本次相关的部分）

| 路径 | 角色 | 现状 |
|---|---|---|
| `scripts/upstream-compat.config.json` | 单一真相源（641 行） | 定义所有支持窗口 + 验证 sentinel + 翻译规则 |
| `scripts/generate-plugin-support-window.js` | 生成器 | 从 config 生成 `plugin/support-window.json` |
| `plugin/support-window.json` | 生成产物 | 包含 `macosNativeExperimental` 和 `windowsNativeExperimental` |
| `scripts/check-support-boundary.js` | 边界守卫 | 检查 README/install 脚本里写的版本号与 config 一致 |
| `scripts/verify-upstream-compat.js` | 兼容验证器 | 跑真实 `claude --help` 等命令做 display 审计 |
| `tests/support-window-generation.test.js` | 漂移检查 | 验证 checked-in `plugin/support-window.json` 等于生成结果 |
| `tests/support-boundary-guard.test.js` | 守卫测试 | 9 个用例，覆盖 README 写错版本号会失败 |
| `plugin/manifest.json` | 插件清单 | 当前 `"version": "2.5.0"` |
| `CHANGELOG.md` | 变更日志 | 文件头从 `[2.5.0] - 2026-05-31` 开始 |
| `README.md` | 项目说明 | "支持范围"那张表里写的是 2.1.113-2.1.153 / 2.1.126 |
| `docs/support-matrix.md` | 支持矩阵 | 由 `scripts/generate-support-matrix.js` 生成 |

### 2.2 已有数据点

- 我环境装的是 Claude Code **2.1.201**（已被汉化过）
- `support-window.json` 里 `windowsNativeExperimental.versions` 最后一个是 `2.1.201`，`excluded` 名单已含 2.1.115/125/127/130/134/135/147/149/151/154/155（**这些 2.1.1X5/2.1.1X7 等离散版本号**）
- `notes` 字段已对 2.1.201 标注 "本机配置加入但尚未完成与 2.1.113 - 2.1.153 同等级的窗口验证，使用风险由用户承担"
- 上游 2.1.202-2.1.205 的 cli.js **我看不到**（装到主环境会污染；远端 fetch 解压需要 `node-lief` 处理 native binary wrapper）

### 2.3 关键约束

| 约束 | 来源 |
|---|---|
| 不能污染我自己 Claude Code 环境 | CLAUDE.md "执行动作" + 用户明确说"验证时你不能影响自己" |
| 用户接受"翻译可能残"，但要 2.1.205 出现在支持窗口里 | 用户决策 |
| 项目有"单一真相源"约定（config → 生成） | `tests/support-window-generation.test.js` 第二个用例保证 |
| `support-boundary-guard` 会拦截 install 脚本里写错版本号 | `tests/support-boundary-guard.test.js` 第 120/245 用例 |

---

## 3. 设计

### 3.1 改动清单

| # | 文件 | 变更 | 改前 → 改后 |
|---|---|---|---|
| 1 | `scripts/upstream-compat.config.json` | 改 `support.windowsNativeExperimental.ceiling` | `"2.1.201"` → `"2.1.205"` |
| 2 | `scripts/upstream-compat.config.json` | 追加 `support.windowsNativeExperimental.representatives` | 按版本号升序，在 `2.1.201` 后追加 `["2.1.202", "2.1.203", "2.1.204", "2.1.205"]` |
| 3 | `scripts/upstream-compat.config.json` | 改 `support.windowsNativeExperimental.verification` | 末尾加 `· 2.1.202 PENDING VERIFICATION` 等 4 条 |
| 4 | `scripts/upstream-compat.config.json` | 改 `support.windowsNativeExperimental.notes` | 在 "2.1.201 ..." 那段后追加 "2.1.202-2.1.205 由本机配置扩入，verification 待真机回填" |
| 5 | `scripts/upstream-compat.config.json` | 改 `support.macosNativeExperimental.ceiling` | `"2.1.156"` → `"2.1.205"` |
| 6 | `scripts/upstream-compat.config.json` | 追加 `support.macosNativeExperimental.representatives` | 按版本号升序，在 `2.1.156` 后追加 `["2.1.202", "2.1.203", "2.1.204", "2.1.205"]`（注意：中间 2.1.157-2.1.201 这些版本**本次不动**，按用户"仅升级最近 2-3 个小版本"决策保持原状） |
| 7 | `scripts/upstream-compat.config.json` | 改 `support.macosNativeExperimental.verification` | 末尾加 `· 2.1.202 PENDING VERIFICATION` 等 4 条 |
| 8 | `scripts/upstream-compat.config.json` | 改 `support.macosNativeExperimental.notes` | 末尾追加 "2.1.202-2.1.205 由本机配置扩入，verification 待真机回填" |
| 9 | `plugin/support-window.json` | **跑生成器重生成**，不手改 | 等于 (1)-(8) 跑完的输出 |
| 10 | `plugin/manifest.json` | `"version"` 字段 | `"2.5.0"` → `"2.6.0"` |
| 11 | `CHANGELOG.md` | 文件头加新段 | `## [2.6.0] - 2026-07-09` + 内容 |
| 12 | `README.md` | "支持范围"那张表里两行版本范围 | 扩到 `2.1.113 - 2.1.205` |
| 13 | `docs/support-matrix.md` | **跑生成器重生成** | 表格自动更新 |

**不动**：`plugin/patch-cli.js`、`plugin/cli-translations.json`、`plugin/hooks/*`、`install.sh`、`install.ps1`、`install-gui.ps1`、`plugin/hooks/session-start.ps1`（虽然 git status 显示它 modified，但跟本次升级无关，**不纳入本次改动**）。

### 3.2 verification 字段的"pending"占位

既有 `verification` 字段长这样：
```
"2.1.201 本机配置加入但尚未完成与 2.1.113 - 2.1.153 同等级的窗口验证，使用风险由用户承担"
```

新增 4 个版本统一用：
```
"2.1.202 PENDING VERIFICATION — 由本机配置扩入，verification 待真机回填"
```

理由：
- "PENDING" 大写显眼，搜索 `PENDING` 就能找到所有未完成验证的版本
- 不写 `PASS(...)` 假装通过——**不撒谎**
- 不写 `pending`（小写）——避免和 README/CHANGELOG 里"翻译残"那种小写描述混在一起
- 跟 2.1.201 那条已存在的"尚未完成同等级验证"措辞保持近义

### 3.3 验证步骤（怎么证明没改坏）

执行顺序：

| 步 | 命令 | 期望结果 | 失败动作 |
|---|---|---|---|
| A | `node --test tests/support-window-generation.test.js` | 2/2 pass | 检查生成器与 checked-in 不一致；看 4.4 排错表 |
| B | `node --test tests/*.test.js` | 全绿 | 逐个 `node --test tests/X.test.js` 定位 |
| C | `node scripts/check-support-boundary.js` | `support-boundary-guard: OK` | 看 README/支持矩阵里有没有出现 `2.1.113+` 这种无上限写法 |
| D | `node scripts/check-payload-sources.js` | OK | 检查 plugin/ 用了未发布的代码 |
| E | `node scripts/verify-upstream-compat.js --baseline 2.1.201 --skip-latest --json` | `2.1.201 PASS(...)` | 重新跑 patch，确认 2.1.201 还能用 |
| F | `node scripts/generate-plugin-support-window.js > /dev/null` | 静默 | 改完 config 后再生成一次确认幂等 |
| G | `node scripts/generate-support-matrix.js` | 静默 | 改完 config 后再生成一次确认幂等 |

**未做的验证**（明确告诉用户）：
- 没在真机装 2.1.202-2.1.205 跑 patch
- 没看 2.1.202-2.1.205 的 cli.js 实际英文内容
- 没补新的翻译条目
- 没改 patch-cli.js 兼容新版本的字符串模式

### 3.4 排错速查

| 看到 | 原因 | 修法 |
|---|---|---|
| `support-window-generation.test.js` 第 2 个用例挂 | checked-in 的 support-window.json 没跟 config 同步 | 跑 F |
| `check-support-boundary.js` 报 README 错 | README 还写着 `2.1.113 - 2.1.153` | 改 README |
| `check-payload-sources.js` 报 | plugin 用了未发布的代码 | 看具体哪行，回退 |
| `verify-upstream-compat.js` 2.1.201 挂 | 我手改 config 时打错字段 | diff 一下，对照设计文档 3.1 表格 |
| B 步里 `translations-*.test.js` 挂 | 翻译表校验问题（与本次无关） | 单独排查 |

### 3.5 风险与兜底

| 风险 | 概率 | 后果 | 兜底 |
|---|---|---|---|
| 上游 2.1.202-205 改了 cli.js 的字符串模式，patch 打不上 | 中 | 用户装了 2.1.205 仍然看到部分英文 | 后续按既有流程加翻译条目（已在 lessons.md 记录回归修法） |
| 我手改 config 时打错 excluded/representatives | 中 | 边界守卫挂、用户升级后行为异常 | 3.3 步 A-E 会爆，回退 git diff 重做 |
| 2.1.202-205 整体跳到 2.2.x（semver major） | 低 | 整个升级无效 | 跟版本时再处理 |
| 用户升 2.1.205 报"漏翻" | 高 | 用户体验差 | README + CHANGELOG 显式标注 "PENDING VERIFICATION，请回报漏翻"，按 issue 流程加翻译 |
| `install-gui.ps1` 等 modified 文件冲突 | 低 | 不能合入 | 本次不碰那些文件，让用户自己决定怎么处理 |

---

## 4. 交付清单

### 4.1 改完后必有

- [ ] `plugin/support-window.json` 含 `2.1.202/203/204/205`（4 个新版本）
- [ ] `plugin/manifest.json` 是 `"version": "2.6.0"`
- [ ] `CHANGELOG.md` 头部有 `## [2.6.0] - 2026-07-09` 段
- [ ] `README.md` "支持范围"表里两行写 `2.1.113 - 2.1.205`
- [ ] `docs/support-matrix.md` 是最新生成结果
- [ ] `node --test tests/*.test.js` 全绿
- [ ] `node scripts/check-support-boundary.js` OK
- [ ] `node scripts/check-payload-sources.js` OK
- [ ] `node scripts/verify-upstream-compat.js --baseline 2.1.201 --skip-latest --json` PASS

### 4.2 不确定性 / 跳过项（必告诉用户）

- **没在真机验证 2.1.202-205 的 patch 实际效果**
- **没补新翻译条目**——2.1.202-205 缺什么翻译得用户装后报
- **没改 patch-cli.js**——如果上游改了 cli.js 字符串模式，patch 会打不上
- **没动 `install-gui.ps1` / `install.ps1` / `session-start.ps1`**——它们已在工作树 modified，但与本次升级无关
- **verification 字段用 `PENDING VERIFICATION` 占位**——不是 PASS，搜得到

---

## 5. 实现计划入口

下一步用 `superpowers:writing-plans` 把这份设计转成可执行步骤清单。
