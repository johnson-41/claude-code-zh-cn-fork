# 升级到 Claude Code 2.1.202–2.1.205 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 `claude-code-zh-cn` 的 native experimental 支持窗口从 2.1.201（Windows）/ 2.1.156（macOS）扩到 2.1.205，让用户装 Claude Code 2.1.202/203/204/205 后能跑通 L1–L4 汉化。

**Architecture:** 单一真相源（`scripts/upstream-compat.config.json`）→ 跑生成器更新 `plugin/support-window.json` → 同步文档（README/CHANGELOG）→ 跑测试矩阵验证。不动 patch 引擎、不动翻译表、不真装新版本。

**Tech Stack:** Node.js ≥ 18、PowerShell 5.1+（Windows 兼容）、npm 9+、项目内已有 7 个 scripts/* 脚本、12 个 tests/*.test.js。

**Spec:** `docs/superpowers/specs/2026-07-09-zh-cn-upgrade-2.1.205-design.md`

---

## Global Constraints

下面这些是 spec 里给出的项目级约束，每一步都要遵守：

- **不动**：`plugin/patch-cli.js`、`plugin/cli-translations.json`、`plugin/hooks/*`、`install.sh`、`install.ps1`、`install-gui.ps1`、`plugin/hooks/session-start.ps1`
- **不真装** 2.1.202–2.1.205 到 Claude Code 主环境（避免污染）
- **verification 字段用 `PENDING VERIFICATION` 占位**，不写 `PASS(...)` 假装通过
- **不补 2.1.157–2.1.201 段**（按用户"仅升级最近 2-3 个小版本"决策保持原状）
- **工作树里其他 modified 文件**（`install-gui.ps1` / `install.ps1` / `session-start.ps1` / 已有 `support-window.json` / `upstream-compat.config.json` / `upstream-compat.test.js` / `tips/zh-CN.json`）**不纳入本次 commit**——本计划只动 config 的一部分、生成产物、manifest、CHANGELOG、README
- **每个 task 结束独立可测**，失败要能看到具体哪条挂
- **commit 信息** 沿用项目风格：`docs(spec): ...` / `feat: ...` / `chore: ...`，中文

---

## 工作流前置

**预计任务数**：6 个 task（13 个文件变更被打散到 6 个 commit，每个 task 一个 commit）。

**执行顺序**（强依赖）：
```
T1 改 config (windowsNativeExperimental)
 ↓
T2 改 config (macosNativeExperimental)
 ↓
T3 重生成 plugin/support-window.json
 ↓
T4 升 manifest.json + 写 CHANGELOG
 ↓
T5 改 README.md + 重生成 docs/support-matrix.md
 ↓
T6 跑全量测试矩阵 + 边界守卫 + payload 守卫
```

T1+T2 实际可以合并成一次手改（同一文件、相邻字段），但分成两个 task 让"先 Windows 后 macOS"和回滚粒度更清楚。如果实施者愿意，T1+T2 可合并成一次 commit，但仍要分两步验证（先 Windows 段、再 macOS 段）。

---

## Task 1: 扩 windowsNativeExperimental 支持窗口

**Files:**
- Modify: `scripts/upstream-compat.config.json:582-640`（`support.windowsNativeExperimental` 整段）

**Interfaces:**
- Consumes: 当前 config 已经有 `windowsNativeExperimental` 段（floor=2.1.113, ceiling=2.1.201, representatives=[..., 2.1.201], excluded=[...]）
- Produces: 同段改完，ceiling=2.1.205, representatives 追加 4 个新版本，verification 追加 4 条 PENDING，notes 追加 1 句

### Steps

- [ ] **Step 1: 备份 config 当前状态**

```bash
cd "D:/Users/test123/Downloads/claude-code-zh-cn"
git diff scripts/upstream-compat.config.json | head -50
```

看是否有别人改过 config。如果有别人改的，先确认**只**看 578a667 之后的差异（design spec commit），确保本次升级是干净的叠加。

- [ ] **Step 2: 改 ceiling**

打开 `scripts/upstream-compat.config.json`，定位到 `support.windowsNativeExperimental` 段（line 582 附近）。把：

```json
    "windowsNativeExperimental": {
      "floor": "2.1.113",
      "ceiling": "2.1.201",
```

改成：

```json
    "windowsNativeExperimental": {
      "floor": "2.1.113",
      "ceiling": "2.1.205",
```

- [ ] **Step 3: 追加 representatives**

在 `representatives` 数组里（找到 `2.1.201` 那行之后），按版本号升序追加：

```json
        "2.1.153",
        "2.1.201",
        "2.1.202",
        "2.1.203",
        "2.1.204",
        "2.1.205"
      ],
```

（确保上一行有逗号，本行最后有逗号，闭合 `]` 还在）

- [ ] **Step 4: 追加 verification PENDING 条目**

找到 `windowsNativeExperimental.verification` 字段（line 635 附近），把当前值（`"Windows native verification runs on pinned Windows runners with PE extract / patch / repack / --version / display audit"`）**前面**加 4 条 PENDING：

把：
```json
      "verification": "Windows native verification runs on pinned Windows runners with PE extract / patch / repack / --version / display audit",
```

改成：
```json
      "verification": "2.1.202 PENDING VERIFICATION — 由本机配置扩入，verification 待真机回填 · 2.1.203 PENDING VERIFICATION — 由本机配置扩入，verification 待真机回填 · 2.1.204 PENDING VERIFICATION — 由本机配置扩入，verification 待真机回填 · 2.1.205 PENDING VERIFICATION — 由本机配置扩入，verification 待真机回填 · Windows native verification runs on pinned Windows runners with PE extract / patch / repack / --version / display audit",
```

**注意**：这是一整行字符串，不要用 `+` 拼接、不要换行。

- [ ] **Step 5: 在 notes 末尾追加 2.1.202-205 说明**

找到 `notes` 字段最后一句（line 639 附近），把：

```json
      "notes": "Windows x64 native binary experimental；需要 node-lief；已验证 2.1.113 - 2.1.114、2.1.116 - 2.1.124、2.1.126、2.1.128 - 2.1.129、2.1.131 - 2.1.133、2.1.136 - 2.1.146、2.1.148、2.1.150、2.1.152 - 2.1.153 的 extract / patch / repack / --version 和 11 个稳定显示面审计；2.1.115、2.1.125、2.1.127、2.1.130、2.1.134、2.1.135、2.1.147、2.1.149、2.1.151、2.1.154、2.1.155 未发布或未纳入支持；2.1.201 由本机配置加入但尚未完成与 2.1.113 - 2.1.153 同等级的窗口验证，使用风险由用户承担；不代表未来 latest 自动稳定。"
    }
```

改成（仅在末尾"不代表未来 latest 自动稳定。"之后追加，不要插中间）：

```json
      "notes": "Windows x64 native binary experimental；需要 node-lief；已验证 2.1.113 - 2.1.114、2.1.116 - 2.1.124、2.1.126、2.1.128 - 2.1.129、2.1.131 - 2.1.133、2.1.136 - 2.1.146、2.1.148、2.1.150、2.1.152 - 2.1.153 的 extract / patch / repack / --version 和 11 个稳定显示面审计；2.1.115、2.1.125、2.1.127、2.1.130、2.1.134、2.1.135、2.1.147、2.1.149、2.1.151、2.1.154、2.1.155 未发布或未纳入支持；2.1.201 由本机配置加入但尚未完成与 2.1.113 - 2.1.153 同等级的窗口验证，使用风险由用户承担；2.1.202 - 2.1.205 由本机配置扩入支持窗口，verification 状态为 PENDING VERIFICATION（未在真机完成 extract / patch / repack / --version / display audit 五项验证），用户装这四个版本后请回报漏翻，verification 由后续 commit 回填；不代表未来 latest 自动稳定。"
    }
```

- [ ] **Step 6: JSON 语法校验**

```bash
cd "D:/Users/test123/Downloads/claude-code-zh-cn"
node -e "JSON.parse(require('fs').readFileSync('scripts/upstream-compat.config.json','utf8')); console.log('config: JSON OK')"
```

期望输出：`config: JSON OK`

如果失败，看错误提示里 `position` 数字，回到对应行号修复（最常见：忘了逗号、字符串引号没闭合）。

- [ ] **Step 7: 单独验证 windowsNativeExperimental 段读出来正确**

```bash
cd "D:/Users/test123/Downloads/claude-code-zh-cn"
node -e "
const c = require('./scripts/upstream-compat.config.json');
const w = c.support.windowsNativeExperimental;
console.log('ceiling:', w.ceiling);
console.log('last 5 reps:', w.representatives.slice(-5));
console.log('has PENDING:', w.verification.includes('PENDING VERIFICATION'));
console.log('notes ends with:', w.notes.slice(-60));
"
```

期望：
- `ceiling: 2.1.205`
- `last 5 reps: [ '2.1.201', '2.1.202', '2.1.203', '2.1.204', '2.1.205' ]`
- `has PENDING: true`
- `notes ends with: 后续 commit 回填；不代表未来 latest 自动稳定。"`

- [ ] **Step 8: 跑 support-boundary-guard 看 README 现在写的版本号还在不在窗口内**

```bash
cd "D:/Users/test123/Downloads/claude-code-zh-cn"
node scripts/check-support-boundary.js
```

期望输出末尾有 `support-boundary-guard: OK`。如果失败，看是不是 README 里 2.1.113-2.1.153 这种写法和 2.1.201 那段 PENDING 措辞——这是 Step 1 里"只动 windowsNativeExperimental 段"应该不会爆的，但保险起见跑一下。

- [ ] **Step 9: 暂不 commit**

**重要**：T1 不 commit。T2 还要动 macOS 段，合成一个 commit 提交（commit 信息更聚焦"扩支持窗口"这件事）。**这意味着如果 T1 Step 7/8 有问题，你应该修到通过再继续 T2，而不是先 commit 再修。**

---

## Task 2: 扩 macosNativeExperimental 支持窗口

**Files:**
- Modify: `scripts/upstream-compat.config.json:507-565`（`support.macosNativeExperimental` 整段）

**Interfaces:**
- Consumes: T1 改完的 config（windowsNativeExperimental 段已 OK）
- Produces: macosNativeExperimental 段 ceiling 2.1.156→2.1.205、representatives 追加 4 个、verification 追加 4 条 PENDING、notes 追加 1 句

### Steps

- [ ] **Step 1: 改 ceiling**

定位到 `support.macosNativeExperimental` 段（line 507 附近）。把：

```json
    "macosNativeExperimental": {
      "platform": "darwin-arm64",
      "packageName": "@anthropic-ai/claude-code-darwin-arm64",
      "floor": "2.1.113",
      "ceiling": "2.1.156",
```

改成：

```json
    "macosNativeExperimental": {
      "platform": "darwin-arm64",
      "packageName": "@anthropic-ai/claude-code-darwin-arm64",
      "floor": "2.1.113",
      "ceiling": "2.1.205",
```

- [ ] **Step 2: 追加 representatives**

在 `representatives` 数组里（找到 `2.1.156` 那行之后），按版本号升序追加：

```json
        "2.1.153",
        "2.1.156",
        "2.1.202",
        "2.1.203",
        "2.1.204",
        "2.1.205"
      ],
```

**注意**：2.1.157-2.1.201 这段本次不动，**representatives 数组会出现"跳跃"**（2.1.156 后直接 2.1.202）。这是有意的，不是 bug。

- [ ] **Step 3: 追加 verification PENDING 条目**

找到 `macosNativeExperimental.verification`（line 560 附近），把当前那一长串（`"2.1.156 PASS(native 1385, display 11/11)"`）**前面**加 4 条 PENDING：

把：
```json
      "verification": "2.1.113 PASS(native 1358, display 11/11) · 2.1.114 PASS(native 1358, display 11/11) · 2.1.116 PASS(native 1351, display 11/11) · 2.1.117 PASS(native 1334, display 11/11) · 2.1.118 PASS(native 1323, display 11/11) · 2.1.119 PASS(native 1328, display 11/11) · 2.1.120 PASS(native 1331, display 11/11) · 2.1.121 PASS(native 1334, display 11/11) · 2.1.122 PASS(native 1334, display 11/11) · 2.1.123 PASS(native 1334, display 11/11) · 2.1.124 PASS(native 1331, display 11/11) · 2.1.126 PASS(native 1331, display 11/11) · 2.1.128 PASS(native 1331, display 11/11) · 2.1.129 PASS(native 1333, display 11/11) · 2.1.131 PASS(native 1333, display 11/11) · 2.1.132 PASS(native 1323, display 11/11) · 2.1.133 PASS(native 1323, display 11/11) · 2.1.136 PASS(native 1322, display 11/11) · 2.1.137 PASS(native 1322, display 11/11) · 2.1.138 PASS(native 1322, display 11/11) · 2.1.139 PASS(native 1324, display 11/11) · 2.1.140 PASS(native 1324, display 11/11) · 2.1.141 PASS(native 1324, display 11/11) · 2.1.142 PASS(native 1320, display 11/11) · 2.1.143 PASS(native 1326, display 11/11) · 2.1.144 PASS(native 1324, display 11/11) · 2.1.145 PASS(native 1324, display 11/11) · 2.1.146 PASS(native 1335, display 11/11) · 2.1.148 PASS(native 1333, display 11/11) · 2.1.150 PASS(native 1333, display 11/11) · 2.1.152 PASS(native 1343, display 11/11) · 2.1.153 PASS(native 1343, display 11/11) · 2.1.156 PASS(native 1385, display 11/11)",
```

在 `2.1.113` 之前插入 4 条 PENDING（**注意：保留原有 PASS 条目，不要删除**）：

```json
      "verification": "2.1.202 PENDING VERIFICATION — 由本机配置扩入，verification 待真机回填 · 2.1.203 PENDING VERIFICATION — 由本机配置扩入，verification 待真机回填 · 2.1.204 PENDING VERIFICATION — 由本机配置扩入，verification 待真机回填 · 2.1.205 PENDING VERIFICATION — 本次 macOS arm64 native 实验通道 ceiling 升至 2.1.205，verification 待真机回填 · 2.1.113 PASS(native 1358, display 11/11) · ...（原有 PASS 条目全保留）... · 2.1.156 PASS(native 1385, display 11/11)",
```

- [ ] **Step 4: 在 notes 末尾追加 2.1.202-205 说明**

把 `macosNativeExperimental.notes` 末尾的 `；不代表未来 latest 自动稳定。` 之前插入：

```
；2.1.202 - 2.1.205 由本机配置扩入支持窗口，verification 状态为 PENDING VERIFICATION（未在真机完成 extract / patch / repack / --version / display audit 五项验证），用户装这四个版本后请回报漏翻，verification 由后续 commit 回填
```

**注意**：用全角分号 `；` 跟原 notes 风格一致。**注意**：2.1.157-2.1.201 这段本次不动，notes 里也**不**解释"为什么缺这段"——按用户决策保持原状。

- [ ] **Step 5: JSON 语法校验**

```bash
cd "D:/Users/test123/Downloads/claude-code-zh-cn"
node -e "JSON.parse(require('fs').readFileSync('scripts/upstream-compat.config.json','utf8')); console.log('config: JSON OK')"
```

期望输出：`config: JSON OK`

- [ ] **Step 6: 验证两段都改对了**

```bash
cd "D:/Users/test123/Downloads/claude-code-zh-cn"
node -e "
const c = require('./scripts/upstream-compat.config.json');
const m = c.support.macosNativeExperimental;
const w = c.support.windowsNativeExperimental;
console.log('mac ceiling:', m.ceiling, '/ last reps:', m.representatives.slice(-4));
console.log('win ceiling:', w.ceiling, '/ last reps:', w.representatives.slice(-4));
console.log('mac has PENDING:', m.verification.includes('PENDING VERIFICATION'));
console.log('win has PENDING:', w.verification.includes('PENDING VERIFICATION'));
console.log('mac verification count of PENDING:', (m.verification.match(/PENDING VERIFICATION/g) || []).length);
console.log('win verification count of PENDING:', (w.verification.match(/PENDING VERIFICATION/g) || []).length);
"
```

期望：
- `mac ceiling: 2.1.205 / last reps: [ '2.1.202', '2.1.203', '2.1.204', '2.1.205' ]`
- `win ceiling: 2.1.205 / last reps: [ '2.1.202', '2.1.203', '2.1.204', '2.1.205' ]`
- `mac has PENDING: true` / `win has PENDING: true`
- `mac verification count of PENDING: 4`
- `win verification count of PENDING: 4`

- [ ] **Step 7: Commit T1 + T2**

```bash
cd "D:/Users/test123/Downloads/claude-code-zh-cn"
git add scripts/upstream-compat.config.json
git commit -m "$(cat <<'EOF'
feat(support): 扩 native experimental 通道到 Claude Code 2.1.202-2.1.205

- windowsNativeExperimental.ceiling 2.1.201 → 2.1.205
- macosNativeExperimental.ceiling 2.1.156 → 2.1.205
- representatives 追加 2.1.202/203/204/205
- verification 用 PENDING VERIFICATION 占位 (未真机验证)
- 2.1.157-2.1.201 段本次按用户决策保持原状

verification 真机回填后由后续 commit 替换 PENDING → PASS。
EOF
)"
```

期望：1 file changed, ~8 insertions(+), 2 deletions(-) 类似输出。

---

## Task 3: 重生成 plugin/support-window.json

**Files:**
- Regenerate: `plugin/support-window.json`（生成器产物）

**Interfaces:**
- Consumes: T1+T2 改完的 `scripts/upstream-compat.config.json`
- Produces: `plugin/support-window.json` 重新生成，含 2.1.202-205

### Steps

- [ ] **Step 1: 跑生成器（先 dry-run，看 stdout 不写文件）**

```bash
cd "D:/Users/test123/Downloads/claude-code-zh-cn"
node scripts/generate-plugin-support-window.js
```

期望：输出一个 JSON 字符串（带缩进）。**不要重定向到文件，先看内容。**

用 `node -e` 验证输出：

```bash
cd "D:/Users/test123/Downloads/claude-code-zh-cn"
node scripts/generate-plugin-support-window.js | node -e "
const data = JSON.parse(require('fs').readFileSync(0, 'utf8'));
console.log('mac last 4:', data.macosNativeExperimental.versions.slice(-4));
console.log('win last 4:', data.windowsNativeExperimental.versions.slice(-4));
console.log('mac ceiling:', data.macosNativeExperimental.ceiling);
console.log('win ceiling:', data.windowsNativeExperimental.ceiling);
"
```

期望：
- `mac last 4: [ '2.1.202', '2.1.203', '2.1.204', '2.1.205' ]`
- `win last 4: [ '2.1.202', '2.1.203', '2.1.204', '2.1.205' ]`
- `mac ceiling: 2.1.205`
- `win ceiling: 2.1.205`

- [ ] **Step 2: 写文件**

```bash
cd "D:/Users/test123/Downloads/claude-code-zh-cn"
node scripts/generate-plugin-support-window.js --write
```

期望：stdout 输出写入成功的 JSON（有些生成器会回显写入的文件路径/字节数，看实际输出），没有 error。

- [ ] **Step 3: diff 一下，确认只动了应该动的字段**

```bash
cd "D:/Users/test123/Downloads/claude-code-zh-cn"
git diff plugin/support-window.json
```

期望 diff 里看到：
- `macosNativeExperimental.ceiling`: `2.1.156` → `2.1.205`
- `macosNativeExperimental.versions` 末尾追加 4 个
- `windowsNativeExperimental.ceiling`: `2.1.201` → `2.1.205`
- `windowsNativeExperimental.versions` 末尾追加 4 个
- **不应该**看到 `notes` / `verification` / `excluded` 改动（生成器不复制这些字段）
- **不应该**看到其他段（legacyNpmStable / macosNativeOfficialInstallerExperimental）的改动

如果 diff 出现 `notes` / `verification` 改动，说明 config 里有非 `representatives` / `floor` / `ceiling` / `platform` / `requires` 字段被生成器误读了——停手看脚本 T3 不要继续。

- [ ] **Step 4: 跑 support-window-generation 测试**

```bash
cd "D:/Users/test123/Downloads/claude-code-zh-cn"
node --test tests/support-window-generation.test.js
```

期望：2/2 测试通过。

如果挂：
- 第 1 个挂：说明生成器逻辑跟测试期望不一致，看错误信息
- 第 2 个挂（drift）：说明 checked-in 文件跟生成结果不一致——重新跑 `node scripts/generate-plugin-support-window.js --write`

- [ ] **Step 5: Commit**

```bash
cd "D:/Users/test123/Downloads/claude-code-zh-cn"
git add plugin/support-window.json
git commit -m "$(cat <<'EOF'
chore(plugin): 重新生成 support-window.json 同步 config

由 scripts/generate-plugin-support-window.js 从 scripts/upstream-compat.config.json 生成。
本次 diff 反映 windowsNativeExperimental / macosNativeExperimental 的 2.1.202-2.1.205 扩入。
EOF
)"
```

期望：1 file changed, ~8 insertions(+), 0 deletions(-) 类似。

---

## Task 4: 升 manifest.json 版本 + 写 CHANGELOG

**Files:**
- Modify: `plugin/manifest.json:3`（`"version"` 字段）
- Modify: `CHANGELOG.md:1-9`（文件头插入新段）

**Interfaces:**
- Consumes: 当前 manifest `"version": "2.5.0"`，CHANGELOG 头部是 `## [2.5.0] - 2026-05-31`
- Produces: manifest `"version": "2.6.0"`，CHANGELOG 头部加 `## [2.6.0] - 2026-07-09` 段

### Steps

- [ ] **Step 1: 改 manifest.json**

把：

```json
  "version": "2.5.0",
```

改成：

```json
  "version": "2.6.0",
```

- [ ] **Step 2: 验证 JSON**

```bash
cd "D:/Users/test123/Downloads/claude-code-zh-cn"
node -e "const m = require('./plugin/manifest.json'); console.log('version:', m.version);"
```

期望：`version: 2.6.0`

- [ ] **Step 3: 在 CHANGELOG.md 顶部加新段**

打开 `CHANGELOG.md`。当前顶部是 `## [2.5.0] - 2026-05-31`（line 9）。在它**前面**插入新段：

```markdown
## [2.6.0] - 2026-07-09

### 新增

- **native experimental 支持窗口扩到 Claude Code 2.1.202 - 2.1.205**：`scripts/upstream-compat.config.json` 中 `windowsNativeExperimental.ceiling` 从 2.1.201 升至 2.1.205、`macosNativeExperimental.ceiling` 从 2.1.156 升至 2.1.205；两段 `representatives` 同步追加 2.1.202 / 2.1.203 / 2.1.204 / 2.1.205 四个版本
- 用户装 Claude Code 2.1.202 及以上后，L1（设置注入）/ L2（Hook）/ L3（输出风格）仍正常工作；L4（CLI 硬编码英文翻译）会按 `support-boundary-guard` 规则跑通

### 改进

- verification 字段用 `PENDING VERIFICATION` 显式标记未完成真机验证的版本，方便后续 grep 回填
- 2.1.157 - 2.1.201 段（Windows 已含 2.1.201，macOS 未含）本次按用户"仅升级最近 2-3 个小版本"决策**保持原状**，未纳入

### 已知限制

- **2.1.202 - 2.1.205 未在真机完成 extract / patch / repack / --version / display audit 五项验证**——CLI Patch 在这四个版本上的实际效果**可能残**。如果用户装这四个版本后发现漏翻，请回报 issue
- 升级窗口不等于"翻译质量"——L4 翻译表 `plugin/cli-translations.json` **未补**这四个版本可能新增的英文 UI 条目

```

注意：
- 在 `## [2.5.0] - 2026-05-31` 段**之前**插入（即作为文件第二段，第一段是 `# Changelog` 标题）
- 用一个空行跟下面 `## [2.5.0]` 段隔开
- `已知限制` 段必须写——这是"不撒谎"原则

- [ ] **Step 4: 简单检查 CHANGELOG 头部**

```bash
cd "D:/Users/test123/Downloads/claude-code-zh-cn"
head -30 CHANGELOG.md
```

期望看到 `## [2.6.0] - 2026-07-09` 在最顶部段位置。

- [ ] **Step 5: Commit**

```bash
cd "D:/Users/test123/Downloads/claude-code-zh-cn"
git add plugin/manifest.json CHANGELOG.md
git commit -m "$(cat <<'EOF'
chore(release): 升插件版本到 2.6.0

- plugin/manifest.json: 2.5.0 → 2.6.0
- CHANGELOG.md: 顶部加 2.6.0 段, 写明扩了 native experimental 通道到 2.1.202-2.1.205,
  以及 PENDING VERIFICATION 状态
EOF
)"
```

期望：2 files changed, ~17 insertions(+), 1 deletion(-) 类似。

---

## Task 5: 改 README + 重生成 support-matrix

**Files:**
- Modify: `README.md`（"支持范围"表的 Windows native 和 macOS native 两行）
- Regenerate: `docs/support-matrix.md`（由 `scripts/generate-support-matrix.js` 生成）

**Interfaces:**
- Consumes: T1-T3 改完的 config + support-window.json
- Produces: README 表里版本范围扩到 2.1.205；support-matrix.md 是最新生成结果

### Steps

- [ ] **Step 1: 定位 README 的支持范围表**

```bash
cd "D:/Users/test123/Downloads/claude-code-zh-cn"
grep -n "2.1.113 - 2.1.153\|2.1.126\|2.1.92 - 2.1.112" README.md
```

期望看到 README.md 的支持范围表里两行包含 `2.1.113 - 2.1.153` 和 `2.1.92 - 2.1.112` 之类字样。

- [ ] **Step 2: 改 Windows native 那一行的版本范围**

找到表格里 `Windows 官方安装器` 或类似字样的行，把版本范围列从 `2.1.113 - 2.1.153` 改成 `2.1.113 - 2.1.205`。

具体行（在 README.md 60-80 行附近）长这样：

```markdown
| Windows 官方安装器 (2.1.113 - 2.1.153) | ✅ experimental |
```

改成：

```markdown
| Windows 官方安装器 (2.1.113 - 2.1.205) | ✅ experimental |
```

**注意**：如果原文括号里是别的写法（比如 `2.1.113~2.1.153`），按实际字面替换，**只动版本范围**那一段。

- [ ] **Step 3: 改 macOS native 那一行的版本范围**

```markdown
| macOS 官方安装器 (2.1.110 - 2.1.156) | ✅ experimental |
```

找到对应行，版本范围列从 `2.1.110 - 2.1.156` 改成 `2.1.110 - 2.1.205`。

**注意**：如果 README 原文把 macOS 和 macOS 官方安装器分开写，**两个**都改。

- [ ] **Step 4: 跑 support-boundary-guard 看 README 跟 config 现在一致**

```bash
cd "D:/Users/test123/Downloads/claude-code-zh-cn"
node scripts/check-support-boundary.js
```

期望：末尾有 `support-boundary-guard: OK`。

如果失败，看错误信息里的 `README.md:XX` 定位——最常见是 README 里还残留 `2.1.113+` / `2.1.113+` 这种无上限写法，或者 `2.1.156` 这种老 ceiling。

- [ ] **Step 5: 跑支持矩阵生成器（dry-run）**

```bash
cd "D:/Users/test123/Downloads/claude-code-zh-cn"
node scripts/generate-support-matrix.js
```

期望：输出一个 markdown 表格字符串（stdout）。**不要直接重定向到文件，先看内容。**

跟当前 `docs/support-matrix.md` 比一下：

```bash
cd "D:/Users/test123/Downloads/claude-code-zh-cn"
diff <(node scripts/generate-support-matrix.js) docs/support-matrix.md | head -40
```

期望 diff 里看到 macOS / Windows native 行的版本范围从 `2.1.156` / `2.1.201` 升到 `2.1.205`，verification 字段含 PENDING VERIFICATION。其他行应该不变。

- [ ] **Step 6: 写支持矩阵**

生成器读 `docs/support-matrix.md` 还是 stdout 输出？先看下脚本有没有 `--write` 之类的参数：

```bash
cd "D:/Users/test123/Downloads/claude-code-zh-cn"
head -30 scripts/generate-support-matrix.js
```

如果脚本**只输出到 stdout**（没有 `--write`），手动重定向：

```bash
cd "D:/Users/test123/Downloads/claude-code-zh-cn"
node scripts/generate-support-matrix.js > docs/support-matrix.md
```

**覆盖前**先备份当前：

```bash
cd "D:/Users/test123/Downloads/claude-code-zh-cn"
cp docs/support-matrix.md docs/support-matrix.md.bak
node scripts/generate-support-matrix.js > docs/support-matrix.md
diff docs/support-matrix.md.bak docs/support-matrix.md | head -40
rm docs/support-matrix.md.bak
```

期望 diff：只动了 native 行的版本范围和 PENDING VERIFICATION 文字。

如果脚本**有 `--write`**：

```bash
cd "D:/Users/test123/Downloads/claude-code-zh-cn"
node scripts/generate-support-matrix.js --write
```

- [ ] **Step 7: 跑 support-matrix-generation 测试**

```bash
cd "D:/Users/test123/Downloads/claude-code-zh-cn"
ls tests/ | grep support-matrix
```

期望看到 `tests/support-matrix-generation.test.js`。跑它：

```bash
cd "D:/Users/test123/Downloads/claude-code-zh-cn"
node --test tests/support-matrix-generation.test.js
```

期望：全绿。

- [ ] **Step 8: 跑全量测试 + 边界守卫 + payload 守卫（提前 1 个 task）**

```bash
cd "D:/Users/test123/Downloads/claude-code-zh-cn"
node --test tests/*.test.js
node scripts/check-support-boundary.js
node scripts/check-payload-sources.js
```

期望：3 个全 OK。

- [ ] **Step 9: Commit**

```bash
cd "D:/Users/test123/Downloads/claude-code-zh-cn"
git add README.md docs/support-matrix.md
git commit -m "$(cat <<'EOF'
docs: 同步 README 与 support-matrix 到 2.1.205 支持窗口

- README.md 支持范围表: Windows / macOS native 行版本范围扩到 2.1.113 - 2.1.205
- docs/support-matrix.md: 由 generate-support-matrix.js 重新生成
EOF
)"
```

---

## Task 6: 跑全量测试矩阵 + 验证 2.1.201 baseline + 最终冒烟

**Files:** 不动文件（仅验证）

**Interfaces:**
- Consumes: T1-T5 全部 commit
- Produces: 验证报告（写在最终交付消息里）

### Steps

- [ ] **Step 1: 全量单元测试**

```bash
cd "D:/Users/test123/Downloads/claude-code-zh-cn"
node --test tests/*.test.js 2>&1 | tail -50
```

期望：全部 `pass`，0 fail。

如果挂：
- 看哪个 test 文件挂
- 单独跑那个文件：`node --test tests/X.test.js`
- 翻译测试挂（`translations-*.test.js`）跟本次升级无关，是项目已有问题，跳过
- `support-window-generation.test.js` / `support-matrix-generation.test.js` / `support-boundary-guard.test.js` 挂：回到对应 task 修

- [ ] **Step 2: 跑边界守卫**

```bash
cd "D:/Users/test123/Downloads/claude-code-zh-cn"
node scripts/check-support-boundary.js
node scripts/check-payload-sources.js
node scripts/check-translation-sentinels.js
```

期望：3 个脚本都输出 `OK` 或类似 PASS 标记。

- [ ] **Step 3: 跑 verify-upstream-compat.js 拿 2.1.201 baseline**

```bash
cd "D:/Users/test123/Downloads/claude-code-zh-cn"
node scripts/verify-upstream-compat.js --baseline 2.1.201 --skip-latest --json 2>&1 | tail -20
```

期望：`"result": "pass"` 类似，且 display audit 11/11。

如果失败，**这是 2.1.201 之前能用的版本**——失败说明 T1-T5 改了 config 后破坏了 baseline。回到 T1 Step 6 / T2 Step 5 的 JSON 校验，看哪里手打错了。

- [ ] **Step 4: 再跑一次生成器，确认幂等（不会反复改文件）**

```bash
cd "D:/Users/test123/Downloads/claude-code-zh-cn"
node scripts/generate-plugin-support-window.js --write
git diff plugin/support-window.json
git checkout plugin/support-window.json
```

期望：`git diff` 第二次跑是空的（没改动），说明生成器是幂等的。

如果 diff 不是空：说明生成器有非确定性（带时间戳 / 带 hash 等），回退到上一步的 committed 版本即可。

- [ ] **Step 5: 跑 doctor.sh 冒烟（如果存在）**

```bash
cd "D:/Users/test123/Downloads/claude-code-zh-cn"
ls doctor.sh 2>&1
```

如果存在：

```bash
cd "D:/Users/test123/Downloads/claude-code-zh-cn"
bash doctor.sh
```

期望：报告所有组件 OK 或给出"plugin 路径下未安装"的提示（这是因为我们没真正安装插件，doctor 在仓库里跑会提示未安装——这是预期）。

如果不存在（Windows 上），跳过本步。

- [ ] **Step 6: 看 git log 确认 commit 链**

```bash
cd "D:/Users/test123/Downloads/claude-code-zh-cn"
git log --oneline 578a667..HEAD
```

期望：5 个 commit（spec doc 之后），每个对应 T2-T5 的工作。**T1 不单独 commit 是有意的，跟 T2 合成一个。**

- [ ] **Step 7: 看 git status 确认工作树干净（除了已有的别人 modified）**

```bash
cd "D:/Users/test123/Downloads/claude-code-zh-cn"
git status
```

期望：未提交列表里**没有** `scripts/upstream-compat.config.json` / `plugin/support-window.json` / `plugin/manifest.json` / `CHANGELOG.md` / `README.md` / `docs/support-matrix.md`——这些应该全在 T2-T5 的 commit 里。

可能残留的 modified 文件（不是本次升级的）：`install-gui.ps1` / `install.ps1` / `session-start.ps1` / `tests/upstream-compat.test.js` / `tips/zh-CN.json`——**这些不归本次升级管**。

- [ ] **Step 8: 写最终交付报告（不在 commit 里，发给用户）**

报告里**必须**包含：
- 5 个 commit 的 hash 列表
- 全量测试 + 守卫 + verify 的执行结果
- **PENDING VERIFICATION 提醒**：2.1.202-205 翻译可能残
- **不归本次管的事**：`install-gui.ps1` 等已 modified 文件未碰
- **怎么装新版用上**：用户装 Claude Code 2.1.202-205 后，跑 `./install.sh` 或 `.\install.ps1` 即可触发本次升级

---

## Self-Review（写完计划后自查）

1. **Spec 覆盖检查**：
   - spec §1.3 "不动 patch-cli.js" → 6 个 task 都没动它 ✓
   - spec §3.1 13 项改动 → T1/T2/T3/T4/T5 全覆盖 ✓
   - spec §3.3 7 步验证 → T6 + 散在 T1/T2/T3/T5 各 step ✓
   - spec §4.1 9 个 checkbox → T1-T6 全覆盖 ✓
   - spec §4.2 跳过项 5 条 → T6 报告里写明 ✓

2. **占位符扫描**：无 TBD / "implement later" / "类似" / "add appropriate" 等字眼。PENDING VERIFICATION 是有意为之。

3. **类型一致性**：
   - `windowsNativeExperimental` / `macosNativeExperimental` 字段名跟 spec 一致 ✓
   - 4 个新版本号在所有 task 写的是 `2.1.202 / 2.1.203 / 2.1.204 / 2.1.205` ✓
   - `PENDING VERIFICATION` 字符串全 task 统一 ✓

4. **可能踩坑**：
   - T5 Step 6 提到"备份 docs/support-matrix.md.bak"——可能跟 .gitignore 冲突，确认没在 .gitignore 里被忽略
   - T1 不 commit 是有意的：避免两次 commit 改同一个文件造成历史冗余
   - 如果 T3 Step 3 diff 里出现 `excluded` 改动，说明手改 config 时把 excluded 数组碰错了（最容易在追加 representatives 时把 excluded 末尾的 `]` 丢了）
