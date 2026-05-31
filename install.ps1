#!/usr/bin/env pwsh
# claude-code-zh-cn Windows 安装脚本 (PowerShell)
# 将中文本地化设置合并到 Claude Code 的 settings.json
# 移植自 install.sh - 适配 Windows 原生环境
# 支持 PowerShell 5.1+

param(
    [switch]$UpdateOnly = $false,
    [switch]$SkipBanner = $false,
    [switch]$SkipCliPatch = $false
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# ======== 路径变量 ========
$ScriptDir = $PSScriptRoot
$SettingsFile = "$env:USERPROFILE\.claude\settings.json"
$OverlayFile = "$ScriptDir\settings-overlay.json"
$PluginSrc = "$ScriptDir\plugin"
$PluginDst = "$env:USERPROFILE\.claude\plugins\claude-code-zh-cn"
if ($env:CLAUDE_PLUGIN_ROOT) { $PluginDst = $env:CLAUDE_PLUGIN_ROOT }
$MarkerFile = "$PluginDst\.patched-version"
$SourceRepoFile = "$PluginDst\.source-repo"
$LastUpdateCheckFile = "$PluginDst\.last-update-check"
$LauncherBinDir = "$env:USERPROFILE\.claude\bin"
if ($env:ZH_CN_LAUNCHER_BIN_DIR) { $LauncherBinDir = $env:ZH_CN_LAUNCHER_BIN_DIR }
$SourceRepoOverride = $env:ZH_CN_SOURCE_REPO
$TmpDir = "$env:TEMP\claude-zh-cn"

$CliPatchStatusSummary = "已跳过（未执行 CLI Patch）"
$CliPatchStatusOk = $false

# ======== 帮助函数 ========
function Write-CN {
    param([string]$Msg, [string]$Color = "White")
    Write-Host $Msg -ForegroundColor $Color
}

function banner {
    if ($SkipBanner) { return }
    Write-Host ""
    if ($UpdateOnly) {
        Write-CN "=== Claude Code 界面汉化插件 更新 ===" Blue
    } else {
        Write-CN "=== Claude Code 界面汉化插件 安装 ===" Blue
    }
    Write-Host ""
}

function run-js {
    param([string]$Code, [string[]]$JsArgs)
    $tmp = Join-Path $TmpDir "tmp-$PID-$((Get-Random).ToString('x')).js"
    New-Item -Force -ItemType Directory -Path $TmpDir | Out-Null
    $Code | Out-File -FilePath $tmp -Encoding ascii -NoNewline
    try {
        if ($JsArgs) {
            node $tmp @JsArgs
        } else {
            node $tmp
        }
    } finally {
        Remove-Item $tmp -Force -ErrorAction SilentlyContinue
    }
}

# ======== Settings 合并脚本（单行 JS，无特殊字符） ========
$JS_BACKUP_PRUNE = "var fs=require('fs'),path=require('path');var dir=process.env.ZH_CN_SETTINGS_DIR;try{var all=fs.readdirSync(dir).filter(function(n){return n.indexOf('settings.json.zh-cn-backup.')===0}).sort();var stale=all.slice(0,Math.max(0,all.length-5));for(var i=0;i<stale.length;i++){fs.unlinkSync(path.join(dir,stale[i]))}}catch(e){}"

$JS_BUILD_OVERLAY_FILES = "var fs=require('fs');var base=JSON.parse(fs.readFileSync(process.argv[2],'utf8'));var verbs=JSON.parse(fs.readFileSync(process.argv[3],'utf8'));var tips=JSON.parse(fs.readFileSync(process.argv[4],'utf8'));base.spinnerVerbs=verbs;base.spinnerTipsOverride={excludeDefault:true,tips:tips.tips.map(function(t){return t.text})};process.stdout.write(JSON.stringify(base))"

$JS_DEEP_MERGE_FILES = "var fs=require('fs');var sf=process.argv[2];var ov=process.argv[3];function readJson(f){return JSON.parse(fs.readFileSync(f,'utf8').replace(/^\uFEFF/,''))}var settings=readJson(sf);var overlay=readJson(ov);function dm(b,o){var r={};var k;for(k in b){if(b.hasOwnProperty(k))r[k]=b[k]}for(k in o){if(!o.hasOwnProperty(k))continue;if(r[k]&&typeof r[k]==='object'&&!Array.isArray(r[k])&&o[k]&&typeof o[k]==='object'&&!Array.isArray(o[k])){r[k]=dm(r[k],o[k])}else{r[k]=o[k]}}return r}var m=dm(settings,overlay);fs.writeFileSync(sf,JSON.stringify(m,null,2)+'\n');process.stdout.write('ok')"

$JS_PATCH_REVISION = "var crypto=require('crypto'),fs=require('fs'),path=require('path');var root=process.argv[2];var files=['manifest.json','patch-cli.sh','patch-cli.js','cli-translations.json','bun-binary-io.js','compute-patch-revision.sh','hooks/session-start','hooks/notification','hooks/auto-repatch.sh','hooks/auto-update.sh','lib/common.sh'];var hash=crypto.createHash('sha256');for(var i=0;i<files.length;i++){var f=files[i];var t=path.join(root,f);if(!fs.existsSync(t))continue;hash.update(f);hash.update('\0');hash.update(fs.readFileSync(t));hash.update('\0')}process.stdout.write(hash.digest('hex').slice(0,16))"


# ======== 输出函数 ========
function completion {
    if ($UpdateOnly -or $SkipBanner) { return }
    Write-Host ""
    Write-CN "=== 安装完成！===" Green
    Write-Host ""
    Write-CN "已启用的功能："
    Write-CN "  √ AI 回复语言 → 中文" Green
    Write-CN "  √ Spinner 提示 → 中文（41 条）" Green
    Write-CN "  √ Spinner 动词 → 中文（187 个）" Green
    Write-CN "  √ 会话启动 Hook → 中文上下文注入（Windows PowerShell）" Green
    Write-CN "  √ 通知 Hook → 中文翻译（Windows PowerShell）" Green
    Write-CN "  √ 输出风格 → Chinese" Green
    Write-CN "  √ 自动重 patch → Claude Code 更新后首次会话自动修复（session-start 兜底）" Green
    Write-CN "  √ 自动更新 → 插件发布新 Release 后自动同步" Green
    if ($CliPatchStatusOk) {
        Write-CN "  √ CLI Patch → $CliPatchStatusSummary" Green
    } else {
        Write-CN "  ! CLI Patch → $CliPatchStatusSummary" Yellow
    }
    Write-Host ""
    Write-Host "重启 Claude Code 即可生效。如需卸载，运行：" -NoNewline
    Write-CN ".\uninstall.ps1" Yellow
}

# ======== 依赖检查 ========
function check-deps {
    $hasError = $false

    if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
        Write-CN "错误：需要 node，请先安装 Node.js" Red
        $hasError = $true
    } else {
        $nodeVer = node --version 2>$null
        if (-not $nodeVer) { $nodeVer = "unknown" }
        Write-CN "  √ Node.js $nodeVer" Green
    }

    if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
        Write-CN "错误：需要 npm，请先安装" Red
        $hasError = $true
    } else {
        $npmVer = npm --version 2>$null
        if (-not $npmVer) { $npmVer = "unknown" }
        Write-CN "  √ npm $npmVer" Green
    }

    if (-not $UpdateOnly -and -not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-CN "警告：建议安装 git 以支持自动更新功能" Yellow
    }

    if (-not $UpdateOnly -and -not $SkipBanner) {
        if (-not (Get-Command jq -ErrorAction SilentlyContinue)) {
            Write-CN "提示：建议安装 jq 以获得更好的 JSON 合并支持" Yellow
            Write-Host "  winget install jqlang.jq"
        }
    }

    if ($hasError) { exit 1 }
}

# ======== 路径/安装检测 ========
function find-real-claude {
    if ($env:ZH_CN_REAL_CLAUDE -and (Get-Command $env:ZH_CN_REAL_CLAUDE -ErrorAction SilentlyContinue)) {
        return $env:ZH_CN_REAL_CLAUDE
    }
    $oldPath = $env:PATH
    try {
        $filtered = ($env:PATH -split ';' | Where-Object { $_ -ne $LauncherBinDir }) -join ';'
        $env:PATH = $filtered
        $found = (Get-Command claude -ErrorAction SilentlyContinue)
        if ($found) { return $found.Source }
        return $null
    } finally {
        $env:PATH = $oldPath
    }
}

function detect-install {
    param([string]$ClaudeBin)
    if (-not $ClaudeBin) { return $null }
    $helperFile = $null
    if (Test-Path "$PluginSrc\bun-binary-io.js") {
        $helperFile = "$PluginSrc\bun-binary-io.js"
    } elseif (Test-Path "$PluginDst\bun-binary-io.js") {
        $helperFile = "$PluginDst\bun-binary-io.js"
    }
    if (-not $helperFile) { return $null }
    $result = node $helperFile detect $ClaudeBin 2>$null
    if ($result) { return $result.Trim() }
    $claudeDir = Split-Path -Parent $ClaudeBin
    $cliFile = Join-Path $claudeDir "..\lib\node_modules\@anthropic-ai\claude-code\cli.js"
    $cliFile = [System.IO.Path]::GetFullPath($cliFile)
    if (Test-Path $cliFile) { return "npm:$cliFile" }
    try {
        $npmRoot = (npm root -g 2>$null).Trim()
        $cliFile2 = Join-Path $npmRoot "@anthropic-ai\claude-code\cli.js"
        if (Test-Path $cliFile2) { return "npm:$cliFile2" }
    } catch {}
    return $null
}

# ======== Settings 操作 ========
function ensure-settings {
    if (-not (Test-Path $SettingsFile)) {
        if (-not $UpdateOnly -and -not $SkipBanner) {
            Write-CN "settings.json 不存在，创建新文件" Yellow
        }
        $dir = Split-Path -Parent $SettingsFile
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
        $utf8NoBom = New-Object System.Text.UTF8Encoding $false
        [System.IO.File]::WriteAllText($SettingsFile, '{}', $utf8NoBom)
    }
}

function remove-old-backups {
    $settingsDir = Split-Path -Parent $SettingsFile
    $env:ZH_CN_SETTINGS_DIR = $settingsDir
    run-js $JS_BACKUP_PRUNE
    Remove-Item Env:\ZH_CN_SETTINGS_DIR -ErrorAction SilentlyContinue
}

function build-overlay {
    $baseFile = "$TmpDir\overlay-base-$PID.json"
    $verbsFile = "$TmpDir\overlay-verbs-$PID.json"
    $tipsFile = "$TmpDir\overlay-tips-$PID.json"
    New-Item -Force -ItemType Directory -Path $TmpDir | Out-Null
    [System.IO.File]::Copy($OverlayFile, $baseFile, $true)
    [System.IO.File]::Copy("$ScriptDir\verbs\zh-CN.json", $verbsFile, $true)
    [System.IO.File]::Copy("$ScriptDir\tips\zh-CN.json", $tipsFile, $true)
    try {
        $result = run-js $JS_BUILD_OVERLAY_FILES @($baseFile, $verbsFile, $tipsFile)
    } finally {
        Remove-Item $baseFile, $verbsFile, $tipsFile -Force -ErrorAction SilentlyContinue
    }
    return $result
}

function merge-settings {
    ensure-settings
    if (-not $UpdateOnly) {
        $timestamp = Get-Date -Format "yyyyMMddHHmmss"
        $backupFile = "$SettingsFile.zh-cn-backup.$timestamp"
        Copy-Item $SettingsFile $backupFile
        remove-old-backups
        if (-not $SkipBanner) {
            Write-CN "已备份 settings.json -> $backupFile" Green
        }
    }
    $overlayContent = build-overlay
    $overlayTempFile = "$TmpDir\settings-overlay-$PID.json"
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($overlayTempFile, $overlayContent, $utf8NoBom)
    try {
        $mergeResult = run-js $JS_DEEP_MERGE_FILES @($SettingsFile, $overlayTempFile)
    } finally {
        Remove-Item $overlayTempFile -Force -ErrorAction SilentlyContinue
    }
    if ($mergeResult -ne "ok") {
        Write-CN "错误：settings.json 合并失败" Red
        exit 1
    }
    if (-not $SkipBanner) {
        Write-CN "已更新 settings.json" Green
    }
    if ($PluginDst -and (Test-Path $PluginDst)) {
        $utf8NoBom = New-Object System.Text.UTF8Encoding $false
        [System.IO.File]::WriteAllText("$PluginDst\.settings-overlay-cache.json", $overlayContent, $utf8NoBom)
    }
}

# ======== 插件同步 ========
function sync-plugin {
    if (-not $PluginDst -or $PluginDst -eq "\" -or $PluginDst -eq "/") {
        Write-CN "错误：PLUGIN_DST 非法，拒绝同步" Red
        exit 1
    }
    if (Test-Path $PluginDst) {
        Get-ChildItem $PluginDst -ErrorAction SilentlyContinue | Where-Object {
            -not $_.Name.StartsWith('.')
        } | Remove-Item -Recurse -Force
    }
    New-Item -ItemType Directory -Force -Path $PluginDst | Out-Null
    Copy-Item "$PluginSrc\*" -Destination $PluginDst -Recurse -Force

    $dstHooksJson = "$PluginDst\hooks.json"
    if (Test-Path $dstHooksJson) {
        $hooksContent = [System.IO.File]::ReadAllText($dstHooksJson, [System.Text.Encoding]::UTF8)
        $hooksContent = $hooksContent -replace "/hooks/session-start'", "/hooks/session-start.cmd'"
        $hooksContent = $hooksContent -replace "/hooks/notification'", "/hooks/notification.cmd'"
        $hooksContent | Out-File -FilePath $dstHooksJson -Encoding ascii -NoNewline
    }
    if (-not $SkipBanner) {
        Write-CN "已安装插件 -> $PluginDst" Green
    }
}

# ======== Launcher 安装 ========
function install-launcher {
    if (-not (Test-Path "$PluginSrc\bin\claude-launcher.cmd")) {
        if (-not $SkipBanner) {
            Write-CN "launcher 文件缺失，已跳过 PATH 注入" Yellow
        }
        return
    }
    New-Item -ItemType Directory -Force -Path $LauncherBinDir | Out-Null
    Copy-Item "$PluginSrc\bin\claude-launcher.ps1" "$LauncherBinDir\claude.ps1" -Force
    Copy-Item "$PluginSrc\bin\claude-launcher.cmd" "$LauncherBinDir\claude.cmd" -Force

    $currentUserPath = [Environment]::GetEnvironmentVariable("PATH", "User")
    if ($env:ZH_CN_SKIP_USER_PATH_UPDATE -eq "1") {
        if (-not $SkipBanner) {
            Write-CN "测试模式：已跳过用户 PATH 持久化写入" Yellow
        }
    } elseif ($currentUserPath -notlike "*$LauncherBinDir*") {
        $newPath = $LauncherBinDir
        if ($currentUserPath) { $newPath = "$LauncherBinDir;$currentUserPath" }
        [Environment]::SetEnvironmentVariable("PATH", $newPath, "User")
        if (-not $SkipBanner) {
            Write-CN "已将 launcher 目录加入用户 PATH -> $LauncherBinDir" Green
        }
    }
    if (-not $SkipBanner) {
        Write-CN "已安装 Windows launcher -> $LauncherBinDir" Green
    }
}

# ======== CLI Patch ========
function get-patch-revision {
    param([string]$Root)
    run-js $JS_PATCH_REVISION @($Root)
}

function read-cli-version {
    param([string]$CliFile)
    if (-not (Test-Path $CliFile)) { return "" }
    try {
        foreach ($line in (Get-Content $CliFile -First 10)) {
            if ($line -match '^// Version: (.+)$') {
                return $matches[1]
            }
        }
        return ""
    } catch {
        return ""
    }
}

function patch-npm-cli {
    param([string]$CliFile)
    Write-Host ""
    Write-CN "正在 patch cli.js 硬编码文字..." Blue
    $currentVersion = read-cli-version $CliFile
    $backupFile = "$CliFile.zh-cn-backup"
    $backupVersion = ""
    if (Test-Path $backupFile) {
        $backupVersion = read-cli-version $backupFile
    }
    if ($currentVersion -and $backupVersion -and $currentVersion -eq $backupVersion -and (Test-Path $backupFile)) {
        Copy-Item $backupFile $CliFile -Force
        Write-CN "已从备份恢复原始 cli.js（版本一致: $currentVersion）" Green
    } else {
        Copy-Item $CliFile $backupFile -Force
        Write-CN "已备份 cli.js（版本: $currentVersion）" Green
    }
    $patchScript = Join-Path $PluginSrc "patch-cli.js"
    $translationsFile = Join-Path $PluginSrc "cli-translations.json"
    if (Test-Path $patchScript) {
        $patchCount = node $patchScript $CliFile $translationsFile 2>$null
        if ($patchCount -and [int]$patchCount -gt 0) {
            Write-CN "已 patch cli.js（${patchCount} 处硬编码文字）" Green
            $script:CliPatchStatusSummary = "cli.js 中文化（${patchCount} 处硬编码文字）"
            $script:CliPatchStatusOk = $true
        } else {
            Write-CN "已 patch cli.js（${patchCount} 处硬编码文字）" Green
            $script:CliPatchStatusSummary = "cli.js 无新增改动（可能已是最新状态）"
        }
    }
    $patchRevision = get-patch-revision $PluginDst
    if ($patchRevision -and $currentVersion) {
        "${currentVersion}|${patchRevision}" | Out-File -FilePath $MarkerFile -Encoding ascii -NoNewline
    }
}

function read-native-version {
    param([string]$BinaryPath)
    # 方法1: bun-binary-io.js version
    $helperFile = $null
    if (Test-Path "$PluginSrc\bun-binary-io.js") { $helperFile = "$PluginSrc\bun-binary-io.js" }
    elseif (Test-Path "$PluginDst\bun-binary-io.js") { $helperFile = "$PluginDst\bun-binary-io.js" }
    if ($helperFile) {
        $ver = node $helperFile version $BinaryPath 2>$null
        if ($ver) { return $ver.Trim() }
    }
    # 方法2: --version
    try {
        $output = & $BinaryPath --version 2>$null
        if ($output -match '(\d+\.\d+\.\d+)') { return $matches[1] }
    } catch {}
    return ""
}

function test-supported-native-version {
    param([string]$Version)
    $supportFile = "$PluginSrc\support-window.json"
    if (-not (Test-Path $supportFile)) { return $false }
    $js = @'
var fs=require("fs");
var data=JSON.parse(fs.readFileSync(process.argv[2],"utf8"));
var v=process.argv[3];
var versions=[];
["macosNativeOfficialInstallerExperimental","macosNativeExperimental","windowsNativeExperimental","linuxNativeExperimental"].forEach(function(k){
var e=data[k];if(!e)return;
(Array.isArray(e.versions)?e.versions:[]).forEach(function(x){versions.push(x)})});
process.exit(versions.indexOf(v)>=0?0:1);
'@
    $tmp = Join-Path $env:TEMP "cczh-vercheck-$PID.js"
    $js | Out-File -FilePath $tmp -Encoding ascii -NoNewline
    try { node $tmp $supportFile $Version 2>$null; return $LASTEXITCODE -eq 0 } finally { Remove-Item $tmp -Force -ErrorAction SilentlyContinue }
}

function patch-native-binary {
    param([string]$BinaryPath)
    Write-Host ""
    Write-CN "检测到官方安装器（原生二进制）" Blue
    Write-CN "  二进制路径: $BinaryPath"

    $currentVersion = read-native-version $BinaryPath
    if (-not (test-supported-native-version $currentVersion)) {
        Write-CN "当前原生二进制版本 $currentVersion 暂不支持 CLI Patch，已跳过" Yellow
        $script:CliPatchStatusSummary = "已跳过（原生二进制版本 $currentVersion 暂不支持 CLI Patch）"
        return
    }

    Write-CN "  版本: $currentVersion（experimental）"

    # 检查 node-lief，缺失时自动安装
    $depStatus = node "$PluginSrc\bun-binary-io.js" check-deps 2>$null
    if ($depStatus -ne "ok") {
        Write-CN "正在安装 node-lief（原生二进制 patch 依赖）..." Yellow
        $installResult = npm install -g node-lief 2>&1
        $depStatus2 = node "$PluginSrc\bun-binary-io.js" check-deps 2>$null
        if ($depStatus2 -ne "ok") {
            Write-CN "node-lief 安装失败，请手动运行: npm install -g node-lief" Red
            $script:CliPatchStatusSummary = "已跳过（node-lief 安装失败）"
            return
        }
        Write-CN "  node-lief 安装成功" Green
    }

    $backupPath = "$BinaryPath.zh-cn-backup"
    $backupVersion = ""
    if (Test-Path $backupPath) {
        $backupVersion = read-native-version $backupPath
    }

    # 备份/恢复逻辑
    if ((Test-Path $backupPath) -and $currentVersion -and ($currentVersion -eq $backupVersion)) {
        Write-CN "  从备份恢复原始二进制..."
        Copy-Item $backupPath $BinaryPath -Force
    } else {
        Write-CN "  备份原始二进制..."
        Copy-Item $BinaryPath $backupPath -Force
    }

    # Extract
    $tmpJs = Join-Path $env:TEMP "cczh-extract-$PID.js"
    $extractOk = node "$PluginSrc\bun-binary-io.js" extract $BinaryPath $tmpJs 2>$null
    if (-not $extractOk) {
        Write-CN "提取 JS 失败" Red
        $script:CliPatchStatusSummary = "已跳过（原生二进制提取失败）"
        Remove-Item $tmpJs -Force -ErrorAction SilentlyContinue
        return
    }

    # Patch
    $patchCount = node "$PluginSrc\patch-cli.js" $tmpJs "$PluginSrc\cli-translations.json" 2>$null

    if ($patchCount -and [int]$patchCount -gt 0) {
        # Repack
        $repackOk = node "$PluginSrc\bun-binary-io.js" repack $BinaryPath $tmpJs 2>$null
        if (-not $repackOk) {
            Write-CN "写回二进制失败，正在从备份恢复..." Red
            if (Test-Path $backupPath) { Copy-Item $backupPath $BinaryPath -Force }
            $script:CliPatchStatusSummary = "已跳过（原生二进制写回失败）"
            Remove-Item $tmpJs -Force -ErrorAction SilentlyContinue
            return
        }
        Write-CN "已 patch 原生二进制（$patchCount 处硬编码文字）" Green
        $script:CliPatchStatusSummary = "官方安装器 native 中文化（$patchCount 处硬编码文字）"
        $script:CliPatchStatusOk = $true
    } else {
        Write-CN "未找到需要 patch 的内容" Yellow
        $script:CliPatchStatusSummary = "原生二进制无新增改动"
        $script:CliPatchStatusOk = $true
    }

    Remove-Item $tmpJs -Force -ErrorAction SilentlyContinue

    # 写入 marker
    $finalVersion = read-native-version $BinaryPath
    $finalHash = node "$PluginSrc\bun-binary-io.js" hash $BinaryPath 2>$null
    if (-not $finalHash) { $finalHash = "unknown" }
    $patchRevision = get-patch-revision $PluginDst
    if ($patchRevision -and $finalVersion) {
        "native|$finalVersion|$finalHash|$patchRevision" | Out-File -FilePath $MarkerFile -Encoding ascii -NoNewline
    }
}

function initial-patch {
    $realClaude = find-real-claude
    if (-not $realClaude) {
        Write-CN "未找到 Claude Code，跳过 patch 步骤" Yellow
        $script:CliPatchStatusSummary = "已跳过（未检测到 Claude Code）"
        return
    }
    $installInfo = detect-install $realClaude
    if (-not $installInfo) {
        Write-CN "未找到 Claude Code，跳过 patch 步骤" Yellow
        $script:CliPatchStatusSummary = "已跳过（未检测到 Claude Code）"
        return
    }
    $kind, $target = $installInfo -split ':', 2
    switch ($kind) {
        "npm" {
            if ($target -and (Test-Path $target)) {
                patch-npm-cli $target
            }
        }
        "native-bun" {
            if ($target -and (Test-Path $target)) {
                patch-native-binary $target
            }
        }
        "unknown" {
            Write-CN "当前安装方式暂不支持 CLI Patch，已跳过此步骤" Yellow
            $script:CliPatchStatusSummary = "已跳过（当前安装方式暂不支持 CLI Patch）"
        }
        default {
            Write-CN "未识别的安装类型: $kind" Yellow
            $script:CliPatchStatusSummary = "已跳过（未识别的安装类型: $kind）"
        }
    }
}

# ======== 元数据写入 ========
function write-metadata {
    $sourceRepo = ""
    if ($SourceRepoOverride) {
        $sourceRepo = $SourceRepoOverride
    } elseif ($UpdateOnly -and (Test-Path $SourceRepoFile)) {
        $sourceRepo = [System.IO.File]::ReadAllText($SourceRepoFile, [System.Text.Encoding]::UTF8).Trim()
    } elseif (-not $UpdateOnly) {
        $sourceRepo = $ScriptDir
    }
    if ($sourceRepo) {
        "$sourceRepo" | Out-File -FilePath $SourceRepoFile -Encoding ascii -NoNewline
    }
    $timestamp = [int][double]::Parse((Get-Date (Get-Date).ToUniversalTime() -UFormat %s))
    "$timestamp" | Out-File -FilePath $LastUpdateCheckFile -Encoding ascii -NoNewline
}

# ======== 手动备份 ========
function do-manual-backup {
    Write-Host ""
    Write-CN "正在备份..." Blue
    $backupZip = "$env:USERPROFILE\claude-code-zh-cn-backup.zip"
    $tmpBackup = Join-Path $env:TEMP "cczh-backup-$PID"
    if (Test-Path $tmpBackup) { Remove-Item -Recurse -Force $tmpBackup }
    New-Item -ItemType Directory -Force -Path $tmpBackup | Out-Null

    # settings.json
    if (Test-Path $SettingsFile) {
        Copy-Item $SettingsFile (Join-Path $tmpBackup "settings.json") -Force
        Write-Host "  settings.json"
    }
    # cli.js backup
    $bin = find-real-claude
    $info = detect-install $bin
    if ($info -and $info.StartsWith("npm:")) {
        $cli = $info.Substring(4)
        if (Test-Path "$cli.zh-cn-backup") {
            $cliDir = Join-Path $tmpBackup "cli"
            New-Item -ItemType Directory -Force -Path $cliDir | Out-Null
            Copy-Item "$cli.zh-cn-backup" (Join-Path $cliDir "cli.js.zh-cn-backup") -Force
            Write-Host "  cli.js 备份"
        }
    } elseif ($info -and $info.StartsWith("native-bun:")) {
        $nativePath = $info.Substring(11)
        if (Test-Path "$nativePath.zh-cn-backup") {
            $nativeDir = Join-Path $tmpBackup "native"
            New-Item -ItemType Directory -Force -Path $nativeDir | Out-Null
            Copy-Item "$nativePath.zh-cn-backup" (Join-Path $nativeDir "binary-backup") -Force
            Write-Host "  原生二进制备份"
        }
    }
    # plugin dir
    if (Test-Path $PluginDst) {
        Copy-Item "$PluginDst\*" (Join-Path $tmpBackup "plugin") -Recurse -Force
        Write-Host "  插件目录"
    }
    # settings backups
    $backups = Get-ChildItem "$env:USERPROFILE\.claude\settings.json.zh-cn-backup.*" -ErrorAction SilentlyContinue
    if ($backups) {
        $sbDir = Join-Path $tmpBackup "settings-backups"
        New-Item -ItemType Directory -Force -Path $sbDir | Out-Null
        $backups | ForEach-Object { Copy-Item $_.FullName (Join-Path $sbDir $_.Name) -Force }
        Write-Host "  settings 备份 ($($backups.Count) 个)"
    }

    # zip
    if (Test-Path $backupZip) { Remove-Item $backupZip -Force }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::CreateFromDirectory($tmpBackup, $backupZip)
    Remove-Item -Recurse -Force $tmpBackup
    $size = [math]::Round((Get-Item $backupZip).Length / 1KB, 1)
    Write-Host ""
    Write-CN "备份完成: $backupZip ($size KB)" Green
}

# ======== 卸载 ========
function do-uninstall {
    Write-Host ""
    Write-CN "正在卸载所有汉化..." Blue

    # 移除 launcher
    $removed = $false
    foreach ($f in @("$LauncherBinDir\claude.cmd", "$LauncherBinDir\claude.ps1")) {
        if (Test-Path $f) { Remove-Item $f -Force; $removed = $true }
    }
    if ($removed) { Write-Host "  已移除 launcher" }
    $curPath = [Environment]::GetEnvironmentVariable("PATH", "User")
    if ($curPath -like "*$LauncherBinDir*") {
        $newPath = ($curPath -split ';' | Where-Object { $_ -ne $LauncherBinDir -and $_ -ne "$LauncherBinDir\" }) -join ';'
        [Environment]::SetEnvironmentVariable("PATH", $newPath, "User")
    }

    # 清理 settings
    if (Test-Path $SettingsFile) {
        $delJs = "var fs=require('fs');var f=process.argv[1],s=JSON.parse(fs.readFileSync(f,'utf8'));['language','spinnerTipsEnabled','spinnerTipsOverride','spinnerVerbs'].forEach(function(k){delete s[k]});fs.writeFileSync(f,JSON.stringify(s,null,2)+'\n');"
        run-js $delJs @($SettingsFile)
        Write-Host "  已清理 settings.json"
    }

    # 还原 cli.js（安全方式）
    $bin = find-real-claude
    $info = detect-install $bin
    if ($info -and $info.StartsWith("npm:")) {
        $cli = $info.Substring(4)
        $bak = "$cli.zh-cn-backup"
        $ver = read-cli-version $cli
        if (Test-Path $bak) {
            $bakVer = read-cli-version $bak
            if ($bakVer -eq $ver) {
                $isClean = Select-String -Path $bak -Pattern "Quick safety check" -Quiet
                if ($isClean) {
                    Copy-Item $bak $cli -Force
                    Remove-Item $bak -Force
                    Write-Host "  已还原 cli.js（验证为英文原版）"
                } else {
                    Write-Host "  备份也是汉化版本，跳过还原"
                    Write-Host "  建议运行: npm install -g @anthropic-ai/claude-code@$ver"
                }
            } else {
                Write-Host "  备份版本不一致，跳过还原"
            }
        }
    } elseif ($info -and $info.StartsWith("native-bun:")) {
        $nativePath = $info.Substring(11)
        if (Test-Path "$nativePath.zh-cn-backup") {
            Copy-Item "$nativePath.zh-cn-backup" $nativePath -Force
            Remove-Item "$nativePath.zh-cn-backup" -Force
            Write-Host "  已还原原生二进制"
        }
    }

    # 移除插件目录
    if (Test-Path $PluginDst) {
        Remove-Item -Recurse -Force $PluginDst
        Write-Host "  已移除插件目录"
    }
    # 清理备份
    Get-ChildItem "$env:USERPROFILE\.claude\settings.json.zh-cn-backup.*" -ErrorAction SilentlyContinue | Remove-Item -Force

    Write-Host ""
    Write-CN "卸载完成！重启 Claude Code 即可恢复英文界面" Green
}

# ======== 更新汉化 ========
function do-update {
    Write-Host ""
    Write-CN "正在更新汉化..." Blue

    # 检测已安装
    if (-not (Test-Path $MarkerFile)) {
        Write-CN "未检测到已安装的汉化插件，请先选择「一键汉化」" Yellow
        return
    }
    $marker = Get-Content $MarkerFile -Raw
    Write-Host "  当前标记: $marker"

    # 检测 Claude Code
    $bin = find-real-claude
    $info = detect-install $bin
    if (-not $info) {
        Write-CN "未检测到 Claude Code" Yellow
        return
    }

    $kind, $target = $info -split ':', 2
    $ver = ""
    if ($kind -eq "npm") { $ver = read-cli-version $target }
    elseif ($kind -eq "native-bun") { $ver = read-native-version $target }
    Write-Host "  Claude Code 版本: $ver"

    # 还原备份（安全验证）
    if ($kind -eq "npm" -and $target) {
        $bak = "$target.zh-cn-backup"
        if (Test-Path $bak) {
            $bakVer = read-cli-version $bak
            if ($bakVer -eq $ver) {
                $isClean = Select-String -Path $bak -Pattern "Quick safety check" -Quiet
                if ($isClean) {
                    Copy-Item $bak $target -Force
                    Write-Host "  已从备份恢复原始 cli.js"
                }
            }
        }
    }

    # 更新插件文件
    Write-Host "  更新插件文件..."
    sync-plugin
    merge-settings
    write-metadata
    Write-Host "  插件和设置已更新"

    # 重新 patch
    initial-patch

    Write-Host ""
    Write-CN "更新完成！重启 Claude Code 生效" Green
}

# ======== 交互式向导 ========
function run_install_wizard {
    if ($UpdateOnly -or $SkipBanner) { return }
    if ([Console]::IsInputRedirected) { return }

    Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue

    Write-Host ""
    Write-CN "=== Claude Code 中文本地化 ===" Blue
    Write-Host ""
    Write-Host "  1. 一键汉化      首次使用，安装汉化插件 + 翻译 CLI 界面"
    Write-Host "  2. 更新汉化      Claude Code 更新后，重新同步翻译和补丁"
    Write-Host "  3. 卸载所有汉化   恢复英文原版，清除插件和设置"
    Write-Host "  4. 打开备份文件夹"
    Write-Host "  5. 手动备份       打包备份为 zip 放在用户目录"
    Write-Host ""

    $choice = Read-Host "请选择 (1-5，默认 1)"
    Write-Host ""

    switch ($choice) {
        "2" {
            do-update
            exit 0
        }
        "3" {
            do-uninstall
            exit 0
        }
        "4" {
            $backupDir = "$env:USERPROFILE\.claude"
            if (Test-Path $backupDir) { explorer.exe $backupDir }
            else { Write-CN "备份目录不存在" Yellow }
            exit 0
        }
        "5" {
            do-manual-backup
            exit 0
        }
        default {
            # 选项 1: 一键汉化
            Write-CN "一键汉化" Green
            Write-Host ""
            Write-CN "安装模式：" Blue
            Write-Host "  1. 标准安装（推荐）"
            Write-Host "  2. 仅更新设置（不 patch CLI）"
            Write-Host ""
            $mode = Read-Host "选择模式 (1/2，默认 1)"
            if ($mode -eq "2") {
                $script:SkipCliPatch = $true
                Write-CN "仅更新设置模式" Yellow
            }
            Write-Host ""
        }
    }
}

# ======== 主流程 ========
function Main {
    run_install_wizard
    banner
    check-deps
    sync-plugin
    install-launcher
    merge-settings
    write-metadata
    if (-not $UpdateOnly -and -not $SkipCliPatch) {
        initial-patch
    }
    completion
}

Main
