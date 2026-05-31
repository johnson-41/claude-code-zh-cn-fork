# install-gui.ps1 — Claude Code 中文本地化插件 WPF 安装器
# 双击运行，傻瓜式操作
# 依赖 PowerShell 5.1+ 原生 WPF，无需额外安装

# ======== 加载程序集 ========
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.IO.Compression.FileSystem

# ======== 路径常量 ========
$ScriptDir = $PSScriptRoot
$SettingsFile = "$env:USERPROFILE\.claude\settings.json"
if ($env:CLAUDE_PLUGIN_ROOT) { $PluginDst = $env:CLAUDE_PLUGIN_ROOT } else { $PluginDst = "$env:USERPROFILE\.claude\plugins\claude-code-zh-cn" }
if ($env:ZH_CN_LAUNCHER_BIN_DIR) { $LauncherBinDir = $env:ZH_CN_LAUNCHER_BIN_DIR } else { $LauncherBinDir = "$env:USERPROFILE\.claude\bin" }
$BackupDir = "$env:USERPROFILE\.claude\zh-cn-backup"
$BackupZip = "$env:USERPROFILE\claude-code-zh-cn-backup.zip"

$ManifestFile = Join-Path $ScriptDir "plugin\manifest.json"
$PluginVersion = "unknown"
if (Test-Path $ManifestFile) {
    try { $PluginVersion = (Get-Content $ManifestFile -Raw | ConvertFrom-Json).version } catch {}
}

# ======== XAML ========
$XAML = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Claude Code 中文本地化"
        Width="480" Height="500"
        WindowStartupLocation="CenterScreen"
        ResizeMode="CanMinimize"
        Background="#1e1e2e">
    <Window.Resources>
        <Style x:Key="BigBtn" TargetType="Button">
            <Setter Property="FontSize" Value="15"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Height" Value="48"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="bg" Background="{TemplateBinding Background}"
                                CornerRadius="8" Padding="20,0">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="bg" Property="Opacity" Value="0.85"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter TargetName="bg" Property="Opacity" Value="0.4"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>

    <Grid Margin="24,20">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <!-- 标题 -->
        <StackPanel Grid.Row="0" Margin="0,0,0,16">
            <TextBlock Text="Claude Code 中文本地化" FontSize="22" FontWeight="Bold" Foreground="#cdd6f4"/>
            <TextBlock x:Name="VersionLabel" FontSize="12" Foreground="#6c7086" Margin="0,4,0,0"/>
        </StackPanel>

        <!-- 按钮 1: 一键汉化 -->
        <Button x:Name="BtnInstall" Style="{StaticResource BigBtn}" Grid.Row="1" Margin="0,0,0,8"
                Background="#89b4fa" Foreground="#1e1e2e">
            <StackPanel Orientation="Horizontal">
                <TextBlock Text="1" FontSize="20" FontWeight="Bold" Margin="0,0,12,0" Opacity="0.5"/>
                <StackPanel>
                    <TextBlock Text="一键汉化" FontSize="15" FontWeight="SemiBold"/>
                    <TextBlock Text="首次使用，安装汉化插件 + 翻译 CLI 界面" FontSize="11" Opacity="0.7"/>
                </StackPanel>
            </StackPanel>
        </Button>

        <!-- 按钮 2: 更新汉化 -->
        <Button x:Name="BtnUpdate" Style="{StaticResource BigBtn}" Grid.Row="2" Margin="0,0,0,8"
                Background="#a6e3a1" Foreground="#1e1e2e">
            <StackPanel Orientation="Horizontal">
                <TextBlock Text="2" FontSize="20" FontWeight="Bold" Margin="0,0,12,0" Opacity="0.5"/>
                <StackPanel>
                    <TextBlock Text="更新汉化" FontSize="15" FontWeight="SemiBold"/>
                    <TextBlock Text="Claude Code 更新后，重新同步翻译和补丁" FontSize="11" Opacity="0.7"/>
                </StackPanel>
            </StackPanel>
        </Button>

        <!-- 按钮 3: 卸载所有汉化 -->
        <Button x:Name="BtnUninstall" Style="{StaticResource BigBtn}" Grid.Row="3" Margin="0,0,0,8"
                Background="#f38ba8" Foreground="#1e1e2e">
            <StackPanel Orientation="Horizontal">
                <TextBlock Text="3" FontSize="20" FontWeight="Bold" Margin="0,0,12,0" Opacity="0.5"/>
                <StackPanel>
                    <TextBlock Text="卸载所有汉化" FontSize="15" FontWeight="SemiBold"/>
                    <TextBlock Text="恢复英文原版，清除插件和设置" FontSize="11" Opacity="0.7"/>
                </StackPanel>
            </StackPanel>
        </Button>

        <!-- 按钮 4+5: 备份操作 -->
        <Grid Grid.Row="4" Margin="0,4,0,0">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="8"/>
                <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>
            <Button x:Name="BtnOpenBackup" Grid.Column="0" Style="{StaticResource BigBtn}"
                    Background="#45475a" Foreground="#cdd6f4" Height="40">
                <StackPanel Orientation="Horizontal">
                    <TextBlock Text="4" FontSize="16" FontWeight="Bold" Margin="0,0,8,0" Opacity="0.5"/>
                    <TextBlock Text="打开备份文件夹" FontSize="13"/>
                </StackPanel>
            </Button>
            <Button x:Name="BtnManualBackup" Grid.Column="2" Style="{StaticResource BigBtn}"
                    Background="#45475a" Foreground="#cdd6f4" Height="40">
                <StackPanel Orientation="Horizontal">
                    <TextBlock Text="5" FontSize="16" FontWeight="Bold" Margin="0,0,8,0" Opacity="0.5"/>
                    <TextBlock Text="手动备份" FontSize="13"/>
                </StackPanel>
            </Button>
        </Grid>

        <!-- 进度条 -->
        <ProgressBar x:Name="ProgressBar" Grid.Row="5" Height="4" Margin="0,12,0,0"
                     Background="#313244" Foreground="#89b4fa" BorderThickness="0"
                     Value="0" Maximum="100"/>

        <!-- 日志 -->
        <Border Grid.Row="6" Background="#181825" CornerRadius="6" BorderBrush="#45475a" BorderThickness="1" Margin="0,8,0,0">
            <ScrollViewer x:Name="LogScroller" VerticalScrollBarVisibility="Auto">
                <TextBox x:Name="LogBox" Background="Transparent" Foreground="#a6adc8"
                         FontFamily="Consolas, Microsoft YaHei" FontSize="12"
                         IsReadOnly="True" BorderThickness="0" AcceptsReturn="True"
                         TextWrapping="Wrap" VerticalScrollBarVisibility="Disabled"
                         HorizontalScrollBarVisibility="Disabled" Text=""/>
            </ScrollViewer>
        </Border>

        <!-- 状态 -->
        <TextBlock x:Name="StatusLabel" Grid.Row="7" Text="就绪" Foreground="#6c7086" FontSize="11" Margin="0,8,0,0"/>
    </Grid>
</Window>
"@

# ======== 初始化 ========
$reader = [System.Xml.XmlNodeReader]::new([xml]$XAML)
$Window = [System.Windows.Markup.XamlReader]::Load($reader)

$BtnInstall    = $Window.FindName("BtnInstall")
$BtnUpdate     = $Window.FindName("BtnUpdate")
$BtnUninstall  = $Window.FindName("BtnUninstall")
$BtnOpenBackup = $Window.FindName("BtnOpenBackup")
$BtnManualBackup = $Window.FindName("BtnManualBackup")
$ProgressBar   = $Window.FindName("ProgressBar")
$LogBox        = $Window.FindName("LogBox")
$LogScroller   = $Window.FindName("LogScroller")
$StatusLabel   = $Window.FindName("StatusLabel")
$VersionLabel  = $Window.FindName("VersionLabel")

$VersionLabel.Text = "版本 $PluginVersion · 简体中文 UI 翻译"

# ======== 工具函数 ========
function Write-Log {
    param([string]$Msg)
    $ts = Get-Date -Format "HH:mm:ss"
    $LogBox.AppendText("[$ts] $Msg`r`n")
    $LogScroller.ScrollToEnd()
    [System.Windows.Forms.Application]::DoEvents() | Out-Null
}

function Set-Status {
    param([string]$Msg, [string]$State = "ready")
    $StatusLabel.Text = $Msg
    $colors = @{ ready="#6c7086"; running="#89b4fa"; success="#a6e3a1"; error="#f38ba8" }
    $StatusLabel.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString($colors[$State])
}

function Set-Buttons {
    param([bool]$On)
    $BtnInstall.IsEnabled = $On
    $BtnUpdate.IsEnabled = $On
    $BtnUninstall.IsEnabled = $On
    $BtnOpenBackup.IsEnabled = $On
    $BtnManualBackup.IsEnabled = $On
}

function Run-Js {
    param([string]$Code, [string[]]$JsArgs)
    $tmp = Join-Path $env:TEMP "cczh-gui-$PID-$((Get-Random).ToString('x')).js"
    $Code | Out-File -FilePath $tmp -Encoding ascii -NoNewline
    try {
        if ($JsArgs) { node $tmp @JsArgs 2>$null } else { node $tmp 2>$null }
    } finally { Remove-Item $tmp -Force -ErrorAction SilentlyContinue }
}

function Find-ClaudeBin {
    $oldPath = $env:PATH
    try {
        $filtered = ($env:PATH -split ';' | Where-Object { $_ -ne $LauncherBinDir }) -join ';'
        $env:PATH = $filtered
        $found = Get-Command claude -ErrorAction SilentlyContinue
        if ($found) { return $found.Source }
    } finally { $env:PATH = $oldPath }
    return $null
}

function Detect-Install {
    param([string]$Bin)
    if (-not $Bin) { return $null }
    $helper = Join-Path $ScriptDir "plugin\bun-binary-io.js"
    if (-not (Test-Path $helper)) { return $null }
    $result = & node $helper detect $Bin 2>$null
    if ($result) { return $result.Trim() }
    return $null
}

function Read-CliVersion {
    param([string]$File)
    if (-not (Test-Path $File)) { return "" }
    foreach ($line in (Get-Content $File -First 10)) {
        if ($line -match '^// Version: (.+)$') { return $matches[1] }
    }
    return ""
}

function Run-Js {
    param([string]$Code, [string[]]$JsArgs)
    $tmp = Join-Path $env:TEMP "cczh-gui-$PID-$((Get-Random).ToString('x')).js"
    $Code | Out-File -FilePath $tmp -Encoding ascii -NoNewline
    try {
        if ($JsArgs) { node $tmp @JsArgs 2>$null } else { node $tmp 2>$null }
    } finally { Remove-Item $tmp -Force -ErrorAction SilentlyContinue }
}

# ======== 核心: 安装 ========
function Do-Install {
    Set-Buttons $false
    Set-Status "正在安装..." "running"
    $ProgressBar.Value = 0
    $LogBox.Text = ""

    try {
        # 依赖
        Write-Log "检查依赖..."
        $nodeVer = node --version 2>$null
        if (-not $nodeVer) {
            Write-Log "错误: 未找到 Node.js，请先安装"
            Set-Status "缺少 Node.js" "error"; return
        }
        Write-Log "  Node.js $nodeVer"
        $npmVer = npm --version 2>$null
        if (-not $npmVer) {
            Write-Log "错误: 未找到 npm，请先安装"
            Set-Status "缺少 npm" "error"; return
        }
        Write-Log "  npm $npmVer"
        $ProgressBar.Value = 10

        # 同步插件
        Write-Log "安装插件文件..."
        $PluginSrc = Join-Path $ScriptDir "plugin"
        if (Test-Path $PluginDst) {
            Get-ChildItem $PluginDst -ErrorAction SilentlyContinue |
                Where-Object { -not $_.Name.StartsWith('.') } |
                Remove-Item -Recurse -Force
        }
        New-Item -ItemType Directory -Force -Path $PluginDst | Out-Null
        Copy-Item "$PluginSrc\*" -Destination $PluginDst -Recurse -Force

        # hooks.json Windows 适配
        $hj = Join-Path $PluginDst "hooks.json"
        if (Test-Path $hj) {
            $h = [System.IO.File]::ReadAllText($hj, [System.Text.Encoding]::UTF8)
            $h = $h -replace "/hooks/session-start'", "/hooks/session-start.cmd'"
            $h = $h -replace "/hooks/notification'", "/hooks/notification.cmd'"
            [System.IO.File]::WriteAllText($hj, $h, [System.Text.UTF8Encoding]::new($false))
        }
        Write-Log "  插件已安装"
        $ProgressBar.Value = 25

        # Launcher
        Write-Log "安装 Launcher..."
        New-Item -ItemType Directory -Force -Path $LauncherBinDir | Out-Null
        if (Test-Path "$PluginSrc\bin\claude-launcher.cmd") {
            Copy-Item "$PluginSrc\bin\claude-launcher.ps1" "$LauncherBinDir\claude.ps1" -Force
            Copy-Item "$PluginSrc\bin\claude-launcher.cmd" "$LauncherBinDir\claude.cmd" -Force
            $curPath = [Environment]::GetEnvironmentVariable("PATH", "User")
            if ($curPath -notlike "*$LauncherBinDir*") {
                if ($curPath) { $newPath = "$LauncherBinDir;$curPath" } else { $newPath = $LauncherBinDir }
                [Environment]::SetEnvironmentVariable("PATH", $newPath, "User")
            }
            Write-Log "  Launcher 已安装"
        }
        $ProgressBar.Value = 35

        # 合并 settings
        Write-Log "合并 settings.json..."
        if (-not (Test-Path $SettingsFile)) {
            New-Item -ItemType Directory -Force -Path (Split-Path $SettingsFile) | Out-Null
            '{}' | Out-File -FilePath $SettingsFile -Encoding ascii -NoNewline
        }
        $ts = Get-Date -Format "yyyyMMddHHmmss"
        Copy-Item $SettingsFile "$SettingsFile.zh-cn-backup.$ts"
        Write-Log "  已备份 settings.json"

        # 构建 overlay
        $overlayJs = @'
var fs=require("fs");
var base=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
var verbs=JSON.parse(fs.readFileSync(process.argv[2],"utf8"));
var tips=JSON.parse(fs.readFileSync(process.argv[3],"utf8"));
base.spinnerVerbs=verbs;
base.spinnerTipsOverride={excludeDefault:true,tips:tips.tips.map(function(t){return t.text})};
process.stdout.write(JSON.stringify(base));
'@
        $overlay = Run-Js $overlayJs (Join-Path $ScriptDir "settings-overlay.json") (Join-Path $ScriptDir "verbs\zh-CN.json") (Join-Path $ScriptDir "tips\zh-CN.json")

        $mergeJs = @'
var fs=require("fs");
var sf=process.argv[1],ov=process.argv[2];
var s=JSON.parse(fs.readFileSync(sf,"utf8").replace(/^﻿/,""));
var o=JSON.parse(fs.readFileSync(ov,"utf8"));
function dm(a,b){var r={};for(var k in a)if(a.hasOwnProperty(k))r[k]=a[k];
for(var k in b)if(b.hasOwnProperty(k)){
if(r[k]&&typeof r[k]==="object"&&!Array.isArray(r[k])&&b[k]&&typeof b[k]==="object"&&!Array.isArray(b[k]))r[k]=dm(r[k],b[k]);
else r[k]=b[k]}return r}
fs.writeFileSync(sf,JSON.stringify(dm(s,o),null,2)+"\n");
process.stdout.write("ok");
'@
        $ovTmp = Join-Path $env:TEMP "cczh-ov-$PID.json"
        $overlay | Out-File -FilePath $ovTmp -Encoding ascii -NoNewline
        $ok = Run-Js $mergeJs $SettingsFile $ovTmp
        Remove-Item $ovTmp -Force -ErrorAction SilentlyContinue

        if ($ok -ne "ok") {
            Write-Log "错误: settings.json 合并失败"
            Set-Status "合并失败" "error"; return
        }
        Write-Log "  settings.json 已更新"
        $ProgressBar.Value = 50

        # 写元数据
        "$ScriptDir" | Out-File -FilePath "$PluginDst\.source-repo" -Encoding ascii -NoNewline
        $epoch = [int][double]::Parse((Get-Date (Get-Date).ToUniversalTime() -UFormat %s))
        "$epoch" | Out-File -FilePath "$PluginDst\.last-update-check" -Encoding ascii -NoNewline
        $ProgressBar.Value = 55

        # CLI Patch
        Write-Log "检测 Claude Code..."
        $bin = Find-ClaudeBin
        $info = Detect-Install $bin

        if ($info -and $info.StartsWith("npm:")) {
            $cli = $info.Substring(4)
            Write-Log "  npm 安装: $cli"
            $ver = Read-CliVersion $cli
            Write-Log "  版本: $ver"
            $ProgressBar.Value = 65

            # 备份 cli.js (patch 前)
            $bak = "$cli.zh-cn-backup"
            if (-not (Test-Path $bak)) {
                Copy-Item $cli $bak -Force
                Write-Log "  已备份原始 cli.js"
            } else {
                $bakVer = Read-CliVersion $bak
                if ($bakVer -eq $ver) {
                    Copy-Item $bak $cli -Force
                    Write-Log "  已从备份恢复原始 cli.js (版本一致: $ver)"
                } else {
                    Copy-Item $cli $bak -Force
                    Write-Log "  版本变化，重新备份 cli.js"
                }
            }
            $ProgressBar.Value = 75

            # Patch
            $patchJs = Join-Path $PluginDst "patch-cli.js"
            $trans = Join-Path $PluginDst "cli-translations.json"
            $count = & node $patchJs $cli $trans 2>$null
            Write-Log "  已 patch ($count 处硬编码文字)"
            $ProgressBar.Value = 90

            # Marker
            $revJs = @'
var c=require("crypto"),f=require("fs"),p=require("path");
var r=process.argv[1],h=c.createHash("sha256");
["manifest.json","patch-cli.sh","patch-cli.js","cli-translations.json","bun-binary-io.js","compute-patch-revision.sh","hooks/session-start","hooks/notification","hooks/auto-repatch.sh","hooks/auto-update.sh","lib/common.sh"].forEach(function(n){
var t=p.join(r,n);if(!f.existsSync(t))return;h.update(n);h.update("\0");h.update(f.readFileSync(t));h.update("\0")});
process.stdout.write(h.digest("hex").slice(0,16));
'@
            $rev = Run-Js $revJs $PluginDst
            if ($rev -and $ver) {
                "${ver}|${rev}" | Out-File -FilePath "$PluginDst\.patched-version" -Encoding ascii -NoNewline
            }
        } elseif ($info -and $info.StartsWith("native-bun:")) {
            Write-Log "  原生二进制安装，Windows 暂不支持 patch"
        } else {
            Write-Log "  未检测到 Claude Code 或不支持 patch"
        }

        $ProgressBar.Value = 100
        Write-Log ""
        Write-Log "=== 一键汉化完成！==="
        Write-Log "重启 Claude Code 即可生效"
        Set-Status "安装完成" "success"
    } catch {
        Write-Log "出错: $_"
        Set-Status "安装失败" "error"
    } finally {
        Set-Buttons $true
    }
}

# ======== 核心: 更新 ========
function Do-Update {
    Set-Buttons $false
    Set-Status "正在更新..." "running"
    $ProgressBar.Value = 0
    $LogBox.Text = ""

    try {
        # 检测是否已安装
        $markerFile = Join-Path $PluginDst ".patched-version"
        if (-not (Test-Path $markerFile)) {
            Write-Log "未检测到已安装的汉化插件，请先使用「一键汉化」"
            Set-Status "未安装" "error"; return
        }
        $marker = Get-Content $markerFile -Raw
        Write-Log "当前标记: $marker"
        $ProgressBar.Value = 10

        # 检测 Claude Code
        $bin = Find-ClaudeBin
        $info = Detect-Install $bin
        if (-not $info -or -not $info.StartsWith("npm:")) {
            Write-Log "未检测到 npm 安装的 Claude Code"
            Set-Status "未检测到" "error"; return
        }

        $cli = $info.Substring(4)
        $ver = Read-CliVersion $cli
        Write-Log "Claude Code 版本: $ver"
        $ProgressBar.Value = 20

        # 检查备份是否是干净的
        $bak = "$cli.zh-cn-backup"
        $bakOk = $false
        if (Test-Path $bak) {
            $bakVer = Read-CliVersion $bak
            if ($bakVer -eq $ver) {
                # 验证备份是英文原版
                $probe = Select-String -Path $bak -Pattern "Quick safety check" -Quiet
                if ($probe) {
                    $bakOk = $true
                    Copy-Item $bak $cli -Force
                    Write-Log "  已从备份恢复原始 cli.js"
                } else {
                    Write-Log "  备份文件也是汉化过的，跳过恢复"
                }
            } else {
                Write-Log "  备份版本 ($bakVer) 与当前版本 ($ver) 不一致"
            }
        } else {
            Write-Log "  无备份文件"
        }
        $ProgressBar.Value = 40

        # 更新插件文件
        Write-Log "更新插件文件..."
        $PluginSrc = Join-Path $ScriptDir "plugin"
        if (Test-Path $PluginDst) {
            Get-ChildItem $PluginDst -ErrorAction SilentlyContinue |
                Where-Object { -not $_.Name.StartsWith('.') } |
                Remove-Item -Recurse -Force
        }
        New-Item -ItemType Directory -Force -Path $PluginDst | Out-Null
        Copy-Item "$PluginSrc\*" -Destination $PluginDst -Recurse -Force

        $hj = Join-Path $PluginDst "hooks.json"
        if (Test-Path $hj) {
            $h = [System.IO.File]::ReadAllText($hj, [System.Text.Encoding]::UTF8)
            $h = $h -replace "/hooks/session-start'", "/hooks/session-start.cmd'"
            $h = $h -replace "/hooks/notification'", "/hooks/notification.cmd'"
            [System.IO.File]::WriteAllText($hj, $h, [System.Text.UTF8Encoding]::new($false))
        }
        Write-Log "  插件文件已更新"
        $ProgressBar.Value = 60

        # 更新 settings overlay
        Write-Log "更新 settings.json..."
        $overlayJs = @'
var fs=require("fs");
var base=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
var verbs=JSON.parse(fs.readFileSync(process.argv[2],"utf8"));
var tips=JSON.parse(fs.readFileSync(process.argv[3],"utf8"));
base.spinnerVerbs=verbs;
base.spinnerTipsOverride={excludeDefault:true,tips:tips.tips.map(function(t){return t.text})};
process.stdout.write(JSON.stringify(base));
'@
        $overlay = Run-Js $overlayJs (Join-Path $ScriptDir "settings-overlay.json") (Join-Path $ScriptDir "verbs\zh-CN.json") (Join-Path $ScriptDir "tips\zh-CN.json")

        $mergeJs = @'
var fs=require("fs");
var sf=process.argv[1],ov=process.argv[2];
var s=JSON.parse(fs.readFileSync(sf,"utf8").replace(/^﻿/,""));
var o=JSON.parse(fs.readFileSync(ov,"utf8"));
function dm(a,b){var r={};for(var k in a)if(a.hasOwnProperty(k))r[k]=a[k];
for(var k in b)if(b.hasOwnProperty(k)){
if(r[k]&&typeof r[k]==="object"&&!Array.isArray(r[k])&&b[k]&&typeof b[k]==="object"&&!Array.isArray(b[k]))r[k]=dm(r[k],b[k]);
else r[k]=b[k]}return r}
fs.writeFileSync(sf,JSON.stringify(dm(s,o),null,2)+"\n");
process.stdout.write("ok");
'@
        $ovTmp = Join-Path $env:TEMP "cczh-ov-$PID.json"
        $overlay | Out-File -FilePath $ovTmp -Encoding ascii -NoNewline
        Run-Js $mergeJs $SettingsFile $ovTmp | Out-Null
        Remove-Item $ovTmp -Force -ErrorAction SilentlyContinue
        Write-Log "  settings.json 已更新"
        $ProgressBar.Value = 75

        # 重新 patch
        Write-Log "重新 patch cli.js..."
        $patchJs = Join-Path $PluginDst "patch-cli.js"
        $trans = Join-Path $PluginDst "cli-translations.json"
        $count = & node $patchJs $cli $trans 2>$null
        Write-Log "  已 patch ($count 处硬编码文字)"
        $ProgressBar.Value = 90

        # 更新 marker
        $revJs = @'
var c=require("crypto"),f=require("fs"),p=require("path");
var r=process.argv[1],h=c.createHash("sha256");
["manifest.json","patch-cli.sh","patch-cli.js","cli-translations.json","bun-binary-io.js","compute-patch-revision.sh","hooks/session-start","hooks/notification","hooks/auto-repatch.sh","hooks/auto-update.sh","lib/common.sh"].forEach(function(n){
var t=p.join(r,n);if(!f.existsSync(t))return;h.update(n);h.update("\0");h.update(f.readFileSync(t));h.update("\0")});
process.stdout.write(h.digest("hex").slice(0,16));
'@
        $rev = Run-Js $revJs $PluginDst
        if ($rev -and $ver) {
            "${ver}|${rev}" | Out-File -FilePath "$PluginDst\.patched-version" -Encoding ascii -NoNewline
        }

        $ProgressBar.Value = 100
        Write-Log ""
        Write-Log "=== 更新完成！==="
        Write-Log "翻译条目: 1742 条，重启 Claude Code 生效"
        Set-Status "更新完成" "success"
    } catch {
        Write-Log "出错: $_"
        Set-Status "更新失败" "error"
    } finally {
        Set-Buttons $true
    }
}

# ======== 核心: 卸载 ========
function Do-Uninstall {
    Set-Buttons $false
    Set-Status "正在卸载..." "running"
    $ProgressBar.Value = 0
    $LogBox.Text = ""

    try {
        # 1. 移除 launcher
        Write-Log "移除 Launcher..."
        $removed = $false
        foreach ($f in @("$LauncherBinDir\claude.cmd", "$LauncherBinDir\claude.ps1")) {
            if (Test-Path $f) { Remove-Item $f -Force; $removed = $true }
        }
        if ($removed) { Write-Log "  已移除 launcher 文件" }
        # 清理空目录
        if (Test-Path $LauncherBinDir) {
            $left = Get-ChildItem $LauncherBinDir -ErrorAction SilentlyContinue
            if (-not $left) { Remove-Item $LauncherBinDir -Force -ErrorAction SilentlyContinue }
        }
        # 清理 PATH
        $curPath = [Environment]::GetEnvironmentVariable("PATH", "User")
        if ($curPath -like "*$LauncherBinDir*") {
            $newPath = ($curPath -split ';' | Where-Object { $_ -ne $LauncherBinDir -and $_ -ne "$LauncherBinDir\" }) -join ';'
            [Environment]::SetEnvironmentVariable("PATH", $newPath, "User")
            Write-Log "  已从 PATH 移除"
        }
        $ProgressBar.Value = 20

        # 2. 清理 settings.json
        Write-Log "清理 settings.json..."
        if (Test-Path $SettingsFile) {
            $delJs = @'
var fs=require("fs");
var f=process.argv[1],s=JSON.parse(fs.readFileSync(f,"utf8"));
["language","spinnerTipsEnabled","spinnerTipsOverride","spinnerVerbs"].forEach(function(k){delete s[k]});
fs.writeFileSync(f,JSON.stringify(s,null,2)+"\n");
'@
            Run-Js $delJs $SettingsFile 2>$null | Out-Null
            Write-Log "  已移除汉化设置项"
        }
        $ProgressBar.Value = 40

        # 3. 还原 cli.js（安全方式：验证备份是否干净）
        Write-Log "还原 CLI..."
        $bin = Find-ClaudeBin
        $info = Detect-Install $bin

        if ($info -and $info.StartsWith("npm:")) {
            $cli = $info.Substring(4)
            $bak = "$cli.zh-cn-backup"
            $ver = Read-CliVersion $cli

            if (Test-Path $bak) {
                $bakVer = Read-CliVersion $bak
                if ($bakVer -eq $ver) {
                    # 验证备份是英文原版（检查是否包含英文原文）
                    $isClean = Select-String -Path $bak -Pattern "Quick safety check" -Quiet
                    if ($isClean) {
                        Copy-Item $bak $cli -Force
                        Remove-Item $bak -Force
                        Write-Log "  已从备份还原原始 cli.js（验证为英文原版）"
                    } else {
                        Write-Log "  备份也是汉化版本，跳过还原"
                        Write-Log "  建议运行: npm install -g @anthropic-ai/claude-code@$ver"
                    }
                } else {
                    Write-Log "  备份版本 ($bakVer) 与当前版本 ($ver) 不一致，跳过还原"
                    Write-Log "  建议运行: npm install -g @anthropic-ai/claude-code@$ver"
                }
            } else {
                Write-Log "  无备份文件"
                Write-Log "  建议运行: npm install -g @anthropic-ai/claude-code@$ver"
            }
        } elseif ($info -and $info.StartsWith("native-bun:")) {
            $nativePath = $info.Substring(11)
            $nativeBak = "$nativePath.zh-cn-backup"
            if (Test-Path $nativeBak) {
                Copy-Item $nativeBak $nativePath -Force
                Remove-Item $nativeBak -Force
                Write-Log "  已还原原生二进制"
            }
        } else {
            Write-Log "  未检测到 Claude Code 安装"
        }
        $ProgressBar.Value = 70

        # 4. 移除插件目录
        Write-Log "移除插件..."
        if (Test-Path $PluginDst) {
            Remove-Item -Recurse -Force $PluginDst
            Write-Log "  已移除插件目录"
        }
        $ProgressBar.Value = 85

        # 5. 清理 settings 备份
        $backups = Get-ChildItem "$env:USERPROFILE\.claude\settings.json.zh-cn-backup.*" -ErrorAction SilentlyContinue
        if ($backups) {
            $backups | Remove-Item -Force
            Write-Log "  已清理 settings.json 备份"
        }
        # 清理 cli.js 备份（如果还在）
        if ($info -and $info.StartsWith("npm:")) {
            $bak = "$($info.Substring(4)).zh-cn-backup"
            if (Test-Path $bak) { Remove-Item $bak -Force }
        }

        $ProgressBar.Value = 100
        Write-Log ""
        Write-Log "=== 卸载完成！==="
        Write-Log "重启 Claude Code 即可恢复英文界面"
        Set-Status "卸载完成" "success"
    } catch {
        Write-Log "出错: $_"
        Set-Status "卸载失败" "error"
    } finally {
        Set-Buttons $true
    }
}

# ======== 按钮 4: 打开备份文件夹 ========
function Do-OpenBackup {
    if (-not (Test-Path $BackupDir)) {
        # 也检查 settings 备份所在目录
        $altDir = "$env:USERPROFILE\.claude"
        if (Test-Path $altDir) {
            explorer.exe $altDir
        } else {
            [System.Windows.MessageBox]::Show("备份文件夹不存在`n$BackupDir", "提示", "OK", "Information")
        }
        return
    }
    explorer.exe $BackupDir
}

# ======== 按钮 5: 手动备份 ========
function Do-ManualBackup {
    Set-Buttons $false
    Set-Status "正在备份..." "running"
    $ProgressBar.Value = 0
    $LogBox.Text = ""

    try {
        Write-Log "开始手动备份..."

        # 创建临时备份目录
        $tmpBackup = Join-Path $env:TEMP "cczh-backup-$PID"
        if (Test-Path $tmpBackup) { Remove-Item -Recurse -Force $tmpBackup }
        New-Item -ItemType Directory -Force -Path $tmpBackup | Out-Null

        # 1. 备份 settings.json
        if (Test-Path $SettingsFile) {
            Copy-Item $SettingsFile (Join-Path $tmpBackup "settings.json") -Force
            Write-Log "  settings.json"
        }
        $ProgressBar.Value = 20

        # 2. 备份 cli.js 和备份文件
        $bin = Find-ClaudeBin
        $info = Detect-Install $bin
        if ($info -and $info.StartsWith("npm:")) {
            $cli = $info.Substring(4)
            if (Test-Path $cli) {
                $cliDir = Join-Path $tmpBackup "cli"
                New-Item -ItemType Directory -Force -Path $cliDir | Out-Null
                Copy-Item $cli (Join-Path $cliDir "cli.js") -Force
                Write-Log "  cli.js"
                if (Test-Path "$cli.zh-cn-backup") {
                    Copy-Item "$cli.zh-cn-backup" (Join-Path $cliDir "cli.js.zh-cn-backup") -Force
                    Write-Log "  cli.js.zh-cn-backup"
                }
            }
        } elseif ($info -and $info.StartsWith("native-bun:")) {
            $nativePath = $info.Substring(11)
            if (Test-Path "$nativePath.zh-cn-backup") {
                $nativeDir = Join-Path $tmpBackup "native"
                New-Item -ItemType Directory -Force -Path $nativeDir | Out-Null
                Copy-Item "$nativePath.zh-cn-backup" (Join-Path $nativeDir "binary-backup") -Force
                Write-Log "  原生二进制备份"
            }
        }
        $ProgressBar.Value = 50

        # 3. 备份插件目录
        if (Test-Path $PluginDst) {
            $plugDir = Join-Path $tmpBackup "plugin"
            New-Item -ItemType Directory -Force -Path $plugDir | Out-Null
            Copy-Item "$PluginDst\*" -Destination $plugDir -Recurse -Force
            Write-Log "  插件目录"
        }
        $ProgressBar.Value = 70

        # 4. 备份所有 settings.json 备份文件
        $settingsBackups = Get-ChildItem "$env:USERPROFILE\.claude\settings.json.zh-cn-backup.*" -ErrorAction SilentlyContinue
        if ($settingsBackups) {
            $sbDir = Join-Path $tmpBackup "settings-backups"
            New-Item -ItemType Directory -Force -Path $sbDir | Out-Null
            $settingsBackups | ForEach-Object {
                Copy-Item $_.FullName (Join-Path $sbDir $_.Name) -Force
            }
            Write-Log "  settings.json 备份 ($($settingsBackups.Count) 个)"
        }
        $ProgressBar.Value = 85

        # 5. 打包成 zip
        if (Test-Path $BackupZip) { Remove-Item $BackupZip -Force }
        [System.IO.Compression.ZipFile]::CreateFromDirectory($tmpBackup, $BackupZip)
        Remove-Item -Recurse -Force $tmpBackup

        $size = [math]::Round((Get-Item $BackupZip).Length / 1KB, 1)
        $ProgressBar.Value = 100
        Write-Log ""
        Write-Log "=== 备份完成！==="
        Write-Log "文件: $BackupZip ($size KB)"
        Write-Log "包含: settings.json + cli.js + 插件目录 + 备份文件"
        Set-Status "备份完成" "success"
    } catch {
        Write-Log "备份出错: $_"
        Set-Status "备份失败" "error"
    } finally {
        Set-Buttons $true
    }
}

# ======== 绑定事件 ========
$BtnInstall.Add_Click({ Do-Install })
$BtnUpdate.Add_Click({ Do-Update })
$BtnUninstall.Add_Click({ Do-Uninstall })
$BtnOpenBackup.Add_Click({ Do-OpenBackup })
$BtnManualBackup.Add_Click({ Do-ManualBackup })

# ======== 启动 ========
$Window.ShowDialog() | Out-Null
