#!/usr/bin/env pwsh
# session-start hook for claude-code-zh-cn-fork (Windows PowerShell 版本)
# 1. 注入中文上下文指令
# 2. 检测插件 Release 更新并同步安装态
# 3. 检测 cli.js 版本变更，自动重 patch

$ErrorActionPreference = "SilentlyContinue"

$PluginRoot = if ($env:CLAUDE_PLUGIN_ROOT) {
    $env:CLAUDE_PLUGIN_ROOT
} else {
    "$env:USERPROFILE\.claude\plugins\claude-code-zh-cn-fork"
}
$MarkerFile = Join-Path $PluginRoot ".patched-version"
$SourceRepoFile = Join-Path $PluginRoot ".source-repo"
$LastUpdateCheckFile = Join-Path $PluginRoot ".last-update-check"
$UpdateCheckInterval = if ($env:ZH_CN_UPDATE_CHECK_INTERVAL_SECONDS) {
    [int]$env:ZH_CN_UPDATE_CHECK_INTERVAL_SECONDS
} else { 21600 }
$LauncherBinDir = if ($env:ZH_CN_LAUNCHER_BIN_DIR) {
    $env:ZH_CN_LAUNCHER_BIN_DIR
} else {
    "$env:USERPROFILE\.claude\bin"
}
$TmpDir = "$env:TEMP\cczh-hook-$PID"

# ======== helper: write JS to temp file, execute with node, return stdout ========
function Invoke-JsScript {
    param(
        [string]$Code,
        [string[]]$Args
    )
    $tmp = Join-Path $TmpDir "tmp-$PID-$((Get-Random).ToString('x')).js"
    New-Item -Force -ItemType Directory -Path $TmpDir | Out-Null
    $Code | Out-File -FilePath $tmp -Encoding ascii -NoNewline
    try {
        if ($Args) {
            node $tmp @Args 2>$null
        } else {
            node $tmp 2>$null
        }
    } finally {
        Remove-Item $tmp -Force -ErrorAction SilentlyContinue
    }
}

# ======== helper functions ========

function Read-ManifestVersion($Target) {
    $code = @'
try{const d=JSON.parse(require("fs").readFileSync(process.argv[2],"utf8"));process.stdout.write(String(d.version||""))}catch(e){}
'@
    Invoke-JsScript -Code $code -Args @($Target)
}

function Test-VersionIsNewer($Current, $Latest) {
    $code = @'
function parse(v){return String(v||"").split(".").map(p=>{const n=Number.parseInt(p,10);return Number.isFinite(n)?n:0})}
function cmp(a,b){const m=Math.max(a.length,b.length);for(let i=0;i<m;i++){const l=a[i]||0,r=b[i]||0;if(l>r)return 1;if(l<r)return -1}return 0}
process.exit(cmp(parse(process.argv[2]),parse(process.argv[3]))>0?0:1)
'@
    Invoke-JsScript -Code $code -Args @($Latest, $Current)
    return ($LASTEXITCODE -eq 0)
}

function Find-RealClaudeBinary {
    if ($env:ZH_CN_REAL_CLAUDE -and (Get-Command $env:ZH_CN_REAL_CLAUDE -ErrorAction SilentlyContinue)) {
        return $env:ZH_CN_REAL_CLAUDE
    }
    $oldPath = $env:PATH
    try {
        $filtered = ($env:PATH -split ';' | Where-Object { $_ -ne $LauncherBinDir }) -join ';'
        $env:PATH = $filtered
        return (Get-Command claude -ErrorAction SilentlyContinue).Source
    } finally {
        $env:PATH = $oldPath
    }
}

function Get-PatchRevision($Root) {
    $code = @'
const crypto=require("crypto"),fs=require("fs"),path=require("path");
const root=process.argv[2];
const files=["manifest.json","patch-cli.sh","patch-cli.js","cli-translations.json","bun-binary-io.js","compute-patch-revision.sh","hooks/session-start","hooks/notification","hooks/auto-repatch.sh","hooks/auto-update.sh","lib/common.sh"];
const hash=crypto.createHash("sha256");
for(const f of files){const t=path.join(root,f);if(!fs.existsSync(t))continue;hash.update(f);hash.update("\0");hash.update(fs.readFileSync(t));hash.update("\0")}
process.stdout.write(hash.digest("hex").slice(0,16));
'@
    Invoke-JsScript -Code $code -Args @($Root)
}

function Read-CliVersion($CliFile) {
    $code = @'
const t=require("fs").readFileSync(process.argv[2],"utf8");const m=t.match(/^\/\/ Version: (.+)$/m);process.stdout.write(m?m[1]:"")
'@
    Invoke-JsScript -Code $code -Args @($CliFile)
}

function Test-NpmCliResidue($CliFile) {
    $code = @'
const fs=require("fs");
const probes=["Quick safety check","This command requires approval","Use /btw to ask a quick side question without interrupting Claude\u0027s current work"];
try{const t=fs.readFileSync(process.argv[2],"utf8");const r=probes.filter(p=>t.includes(p));if(r.length>0){process.stdout.write(r.join(" | "));process.exit(0)}}catch(e){}
process.exit(1);
'@
    Invoke-JsScript -Code $code -Args @($CliFile)
    return ($LASTEXITCODE -eq 0)
}

function Read-NativeVersion($BinaryPath) {
    $helperFile = Join-Path $PluginRoot "bun-binary-io.js"
    if (-not (Test-Path $helperFile)) { return "" }
    $v = node $helperFile version "$BinaryPath" 2>$null
    if ($v) { return ($v.Trim()) }
    return ""
}

function Get-NativeHash($BinaryPath) {
    $helperFile = Join-Path $PluginRoot "bun-binary-io.js"
    if (-not (Test-Path $helperFile)) { return "unknown" }
    $h = node $helperFile hash "$BinaryPath" 2>$null
    if ($h) { return ($h.Trim()) }
    return "unknown"
}

function Test-NativeSupportedVersion($Version) {
    $supportFile = Join-Path $PluginRoot "support-window.json"
    if (-not (Test-Path $supportFile)) { return $false }
    if (-not $Version) { return $false }
    $code = @'
const fs=require("fs");
const data=JSON.parse(fs.readFileSync(process.argv[2],"utf8"));
const v=String(process.argv[3]||"");
const versions=[];
["legacyNpmStable","macosNativeOfficialInstallerExperimental","macosNativeExperimental","windowsNativeExperimental","linuxNativeExperimental"].forEach(function(k){var e=data[k];if(!e)return;(Array.isArray(e.versions)?e.versions:[]).forEach(function(x){versions.push(String(x))})});
process.stdout.write(versions.indexOf(v)>=0?"1":"0");
'@
    $r = Invoke-JsScript -Code $code -Args @($supportFile, $Version)
    return ($r -eq "1")
}

function Test-NativeResidue($BinaryPath) {
    $helperFile = Join-Path $PluginRoot "bun-binary-io.js"
    if (-not (Test-Path $helperFile)) { return $true }
    $probeFile = Join-Path $TmpDir "native-probe-$PID.js"
    $extracted = node $helperFile extract "$BinaryPath" "$probeFile" 2>$null
    if (-not $extracted) { return $true }
    if (-not (Test-Path $probeFile)) { return $true }
    try {
        $hasResidue = Select-String -Path $probeFile -Pattern "Quick safety check" -Quiet
        return [bool]$hasResidue
    } finally {
        Remove-Item $probeFile -Force -ErrorAction SilentlyContinue
    }
}

function Repair-NativeBinary($BinaryPath) {
    $helperFile = Join-Path $PluginRoot "bun-binary-io.js"
    if (-not (Test-Path $helperFile)) { return 0 }
    $depStatus = node $helperFile check-deps 2>$null
    if ($depStatus -ne "ok") { return 0 }

    $backupPath = "${BinaryPath}.zh-cn-backup"
    $currentVersion = Read-NativeVersion $BinaryPath
    $backupVersion = if (Test-Path $backupPath) { Read-NativeVersion $backupPath } else { "" }

    if ((Test-Path $backupPath) -and $currentVersion -and ($currentVersion -eq $backupVersion)) {
        Copy-Item $backupPath $BinaryPath -Force
    } else {
        Copy-Item $BinaryPath $backupPath -Force
    }

    $tmpJs = Join-Path $TmpDir "native-extract-$PID.js"
    $extractOk = node $helperFile extract "$BinaryPath" "$tmpJs" 2>$null
    if ($extractOk -ne "ok") {
        if (Test-Path $backupPath) { Copy-Item $backupPath $BinaryPath -Force }
        Remove-Item $tmpJs -Force -ErrorAction SilentlyContinue
        return 0
    }

    $patchCount = node (Join-Path $PluginRoot "patch-cli.js") "$tmpJs" (Join-Path $PluginRoot "cli-translations.json") 2>$null
    if (-not $patchCount) { $patchCount = "0" }
    $patchCountInt = 0
    [int]::TryParse($patchCount, [ref]$patchCountInt) | Out-Null

    if ($patchCountInt -gt 0) {
        $repackOk = node $helperFile repack "$BinaryPath" "$tmpJs" 2>$null
        if ($repackOk -ne "ok") {
            if (Test-Path $backupPath) { Copy-Item $backupPath $BinaryPath -Force }
            Remove-Item $tmpJs -Force -ErrorAction SilentlyContinue
            return 0
        }
    }
    Remove-Item $tmpJs -Force -ErrorAction SilentlyContinue
    return $patchCountInt
}

function Get-InstallInfo($ClaudeBin) {
    if (-not $ClaudeBin) { return $null }
    $helperFile = Join-Path $PluginRoot "bun-binary-io.js"
    if (-not (Test-Path $helperFile)) { return $null }
    node $helperFile detect "$ClaudeBin" 2>$null
}

# ======== Auto Update ========
$AutoUpdateMsg = ""
$SourceRepo = $null
if (Test-Path $SourceRepoFile) {
    $SourceRepo = [System.IO.File]::ReadAllText($SourceRepoFile, [System.Text.Encoding]::UTF8) -replace '\r?\n', ''
}

$hasLocalGit = $SourceRepo -and (Test-Path "$SourceRepo\.git")
if ($env:ZH_CN_DISABLE_AUTO_UPDATE -ne "1") {
    $now = [DateTimeOffset]::Now.ToUnixTimeSeconds()
    $last = 0
    if (Test-Path $LastUpdateCheckFile) {
        $raw = [System.IO.File]::ReadAllText($LastUpdateCheckFile, [System.Text.Encoding]::UTF8) -replace '\r?\n', ''
        [int]::TryParse($raw, [ref]$last) | Out-Null
    }
    $shouldCheck = ($UpdateCheckInterval -eq 0) -or (($now - $last) -ge $UpdateCheckInterval)
    if ($shouldCheck) {
        [string]$now | Out-File -FilePath $LastUpdateCheckFile -Encoding ascii -NoNewline

        $LocalVersion = Read-ManifestVersion "$PluginRoot\manifest.json"
        $LatestTag = $null
        $LatestVersion = $null

        if ($LocalVersion) {
            # 方式一：本地 git 仓库
            if ($hasLocalGit) {
                Push-Location $SourceRepo
                try {
                    $fetchJob = Start-Job -ScriptBlock {
                        param($repo)
                        Set-Location $repo
                        git fetch --tags --quiet 2>$null
                    } -ArgumentList $SourceRepo
                    $null = Wait-Job $fetchJob -Timeout 15
                    Remove-Job $fetchJob -Force -ErrorAction SilentlyContinue
                    $LatestTag = (git tag -l 'v*' --sort=-version:refname 2>$null | Select-Object -First 1)
                } finally {
                    Pop-Location
                }
            }

            # 方式二：GitHub API fallback（无本地仓库或 git 获取失败时）
            if (-not $LatestTag -and $env:ZH_CN_NO_GITHUB_FALLBACK -ne "1") {
                try {
                    $apiUrl = "https://api.github.com/repos/Lijianpeng-Arch/claude-code-zh-cn-fork/releases/latest"
                    $release = Invoke-RestMethod -Uri $apiUrl -TimeoutSec 15 -ErrorAction Stop
                    if ($release.tag_name) {
                        $LatestTag = $release.tag_name
                    }
                } catch {}
            }

            $LatestVersion = if ($LatestTag) { $LatestTag -replace '^v', '' } else { $null }
            if ($LatestTag -and $LatestVersion -and $LocalVersion -match '^\d+\.\d+\.\d+' -and $LatestVersion -match '^\d+\.\d+\.\d+') {
                if (Test-VersionIsNewer $LocalVersion $LatestVersion) {
                    $stagingDir = Join-Path ([System.IO.Path]::GetTempPath()) "cczh-update-${PID}"
                    try {
                        New-Item -ItemType Directory -Force -Path $stagingDir | Out-Null
                        $exported = $false

                        # 方式一：从本地仓库导出
                        if ($hasLocalGit) {
                            Push-Location $SourceRepo
                            try {
                                git archive --format=tar $LatestTag install.ps1 install.sh compute-patch-revision.sh settings-overlay.json verbs tips plugin 2>$null | tar -xf - -C $stagingDir 2>$null
                                $exported = $?
                            } finally { Pop-Location }
                        }

                        # 方式二：从 GitHub 下载 tar.gz
                        if (-not $exported) {
                            try {
                                $downloadUrl = "https://github.com/Lijianpeng-Arch/claude-code-zh-cn-fork/archive/refs/tags/${LatestTag}.tar.gz"
                                $tarFile = Join-Path $stagingDir "release.tar.gz"
                                Invoke-WebRequest -Uri $downloadUrl -OutFile $tarFile -TimeoutSec 30 -ErrorAction Stop
                                tar -xzf $tarFile -C $stagingDir --strip-components=1 2>$null
                                $exported = $?
                                Remove-Item $tarFile -Force -ErrorAction SilentlyContinue
                            } catch {}
                        }

                        if ($exported) {
                            $stagingValid = (Test-Path "$stagingDir\install.ps1") -and (Test-Path "$stagingDir\install.sh") -and
                                (Test-Path "$stagingDir\settings-overlay.json") -and (Test-Path "$stagingDir\compute-patch-revision.sh") -and
                                (Test-Path "$stagingDir\plugin\manifest.json") -and (Test-Path "$stagingDir\plugin\patch-cli.sh") -and
                                (Test-Path "$stagingDir\plugin\patch-cli.js") -and (Test-Path "$stagingDir\plugin\cli-translations.json") -and
                                (Test-Path "$stagingDir\plugin\bun-binary-io.js") -and
                                (Test-Path "$stagingDir\verbs\zh-CN.json") -and (Test-Path "$stagingDir\tips\zh-CN.json")
                            if ($stagingValid) {
                                $env:CLAUDE_PLUGIN_ROOT = $PluginRoot
                                $env:ZH_CN_SOURCE_REPO = if ($SourceRepo) { $SourceRepo } else { "" }
                                $env:ZH_CN_SKIP_BANNER = "1"
                                powershell -NoProfile -ExecutionPolicy Bypass -File "$stagingDir\install.ps1" -UpdateOnly -SkipBanner 2>$null
                                Remove-Item Env:\CLAUDE_PLUGIN_ROOT, Env:\ZH_CN_SOURCE_REPO, Env:\ZH_CN_SKIP_BANNER -ErrorAction SilentlyContinue
                                $AutoUpdateMsg = "插件已从 v${LocalVersion} 更新到 v${LatestVersion}"
                            }
                        }
                    } catch {} finally {
                        if (Test-Path $stagingDir) {
                            Remove-Item -Recurse -Force $stagingDir -ErrorAction SilentlyContinue
                        }
                    }
                }
            }
        }
    }
}

# ======== Auto Patch ========
$AutoPatchMsg = ""
$ClaudeBin = Find-RealClaudeBinary
$InstallInfo = $null
if ($ClaudeBin) {
    $InstallInfo = Get-InstallInfo $ClaudeBin
}

if ($InstallInfo) {
    $Kind, $Target = $InstallInfo -split ':', 2
    if ($Kind -eq "npm" -and $Target -and (Test-Path $Target)) {
        $CurrentVersion = Read-CliVersion $Target
        $PatchRevision = Get-PatchRevision $PluginRoot
        $CurrentMarker = $CurrentVersion
        if ($PatchRevision) { $CurrentMarker = "${CurrentVersion}|${PatchRevision}" }
        $PatchedVersion = $null
        if (Test-Path $MarkerFile) {
            $PatchedVersion = [System.IO.File]::ReadAllText($MarkerFile, [System.Text.Encoding]::UTF8) -replace '\r?\n', ''
        }
        $hasResidue = Test-NpmCliResidue $Target
        if ($CurrentMarker -ne $PatchedVersion -or $hasResidue) {
            if (Test-Path "$PluginRoot\patch-cli.js") {
                $patchCount = node "$PluginRoot\patch-cli.js" "$Target" "$PluginRoot\cli-translations.json" 2>$null
                "$CurrentMarker" | Out-File -FilePath $MarkerFile -Encoding ascii -NoNewline
                if ($patchCount -and [int]$patchCount -gt 0) {
                    $AutoPatchMsg = "（已自动 patch ${patchCount} 处硬编码文字）"
                }
            }
        }
    } elseif ($Kind -eq "native-bun" -and $Target -and (Test-Path $Target)) {
        $CurrentVersion = Read-NativeVersion $Target
        $CurrentHash = Get-NativeHash $Target
        $PatchRevision = Get-PatchRevision $PluginRoot
        $CurrentMarker = "native|${CurrentVersion}|${CurrentHash}"
        if ($PatchRevision) { $CurrentMarker = "${CurrentMarker}|${PatchRevision}" }
        $PatchedVersion = $null
        if (Test-Path $MarkerFile) {
            $PatchedVersion = [System.IO.File]::ReadAllText($MarkerFile, [System.Text.Encoding]::UTF8) -replace '\r?\n', ''
        }
        $hasResidue = Test-NativeResidue $Target
        if ($CurrentMarker -ne $PatchedVersion -or $hasResidue) {
            if ($CurrentVersion -and (Test-NativeSupportedVersion $CurrentVersion)) {
                $patchCount = Repair-NativeBinary $Target
                if ($patchCount -gt 0) {
                    $AutoPatchMsg = "（已自动 patch 原生二进制 ${patchCount} 处硬编码文字 — Claude Code ${CurrentVersion}）"
                }
                $FinalHash = Get-NativeHash $Target
                $FinalMarker = "native|${CurrentVersion}|${FinalHash}"
                if ($PatchRevision) { $FinalMarker = "${FinalMarker}|${PatchRevision}" }
                $FinalMarker | Out-File -FilePath $MarkerFile -Encoding ascii -NoNewline
            }
        }
    }
}

# ======== Cleanup tmp dir ========
if (Test-Path $TmpDir) {
    Remove-Item -Recurse -Force $TmpDir -ErrorAction SilentlyContinue
}

# ======== Build output context ========
$rawInput = [Console]::In.ReadToEnd()

$ctxLines = @(
    "## 中文本地化提示",
    "",
    "你正在使用中文本地化版本。请遵循以下规则：",
    "- 默认使用中文（简体）回复用户",
    "- 技术术语保留英文（如 API、PR、git、npm、React、TypeScript 等）",
    "- 使用中文标点符号（，。！？：；「」）",
    "- 错误信息尽量提供中文解释，附带英文原文",
    "- 保持简洁直接的风格",
    "- 代码注释使用中文",
    "- 日期格式使用 YYYY年MM月DD日",
    "",
    "## 常见错误信息翻译参考",
    "- Permission denied → 权限被拒绝",
    "- File not found → 文件未找到",
    "- Command not found → 命令未找到",
    "- Connection refused → 连接被拒绝",
    "- Timeout → 超时",
    "- Rate limited → 请求频率受限",
    "- Internal server error → 服务器内部错误",
    "- Unauthorized → 未授权",
    "- Forbidden → 禁止访问",
    "- Not found → 未找到"
)

if ($AutoUpdateMsg) {
    $ctxLines += @("", "## 自动更新", $AutoUpdateMsg)
}
if ($AutoPatchMsg) {
    $ctxLines += @("", "## 自动修复", $AutoPatchMsg)
}

$result = @{
    hookSpecificOutput = @{
        hookEventName    = "SessionStart"
        additionalContext = ($ctxLines -join "`n")
    }
}
$result | ConvertTo-Json -Compress -Depth 10
