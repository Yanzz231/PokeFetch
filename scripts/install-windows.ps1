param(
    [switch]$SkipShellHooks,
    [switch]$ForceConfig
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$DataRoot = Join-Path $env:LOCALAPPDATA 'PokeFetch'
$ConfigDir = Join-Path $env:USERPROFILE '.config\pokefetch'
$ConfigPath = Join-Path $ConfigDir 'config.json'
$CmdAutorun = Join-Path $DataRoot 'cmd-autorun.cmd'
$PowerShellProfile = $PROFILE.CurrentUserAllHosts
$OhMyPoshConfig = Join-Path $env:USERPROFILE 'Documents\custom_theme.json'
$ClinkDir = Join-Path $env:LOCALAPPDATA 'clink'
$ClinkLua = Join-Path $ClinkDir 'oh-my-posh.lua'

py -m pip install --user -e $Root
$ScriptsPath = py -c "import sysconfig; print(sysconfig.get_path('scripts', scheme='nt_user'))"
$ShimDir = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps'
$ShimPath = Join-Path $ShimDir 'pokefetch.cmd'
$UserPath = [Environment]::GetEnvironmentVariable('Path', 'User')
foreach ($PathItem in @($ScriptsPath, $ShimDir)) {
    if ($UserPath -notlike "*$PathItem*") {
        $UserPath = $UserPath.TrimEnd(';') + ';' + $PathItem
    }
    if ($env:Path -notlike "*$PathItem*") {
        $env:Path = $env:Path + ';' + $PathItem
    }
}
[Environment]::SetEnvironmentVariable('Path', $UserPath, 'User')
if (-not (Test-Path -LiteralPath $ShimDir)) {
    New-Item -ItemType Directory -Path $ShimDir | Out-Null
}
Set-Content -LiteralPath $ShimPath -Encoding ASCII -Value "@echo off`r`npy -m src %*`r`n"

if (-not (Test-Path -LiteralPath $DataRoot)) {
    New-Item -ItemType Directory -Path $DataRoot | Out-Null
}

if (-not (Test-Path -LiteralPath $ConfigDir)) {
    New-Item -ItemType Directory -Path $ConfigDir | Out-Null
}

if ($ForceConfig -or -not (Test-Path -LiteralPath $ConfigPath)) {
    $config = [ordered]@{
        theme = 'side-unicode'
        sprites_dir = $null
        show_on_cls = $true
    } | ConvertTo-Json -Depth 4
    Set-Content -LiteralPath $ConfigPath -Value ($config + "`n") -Encoding UTF8
}

if (-not (Test-Path -LiteralPath $ClinkDir)) {
    New-Item -ItemType Directory -Path $ClinkDir | Out-Null
}
if (Test-Path -LiteralPath $OhMyPoshConfig) {
    $OhMyPoshConfigForLua = $OhMyPoshConfig.Replace('\', '/').Replace('"', '\"')
    Set-Content -LiteralPath $ClinkLua -Encoding UTF8 -Value "load(io.popen('oh-my-posh init cmd --config \"$OhMyPoshConfigForLua\"'):read(\"*a\"))()`n"
}
if (Test-Path -LiteralPath 'C:\Program Files (x86)\clink\clink.bat') {
    & 'C:\Program Files (x86)\clink\clink.bat' set clink.logo none | Out-Null
}

if (-not $SkipShellHooks) {
    $psBlock = @'
function Invoke-PokeFetch {
    if ($env:POKEFETCH_DISABLE -ne '1') {
        pokefetch --shell-name "PowerShell $($PSVersionTable.PSVersion)" show
    }
}

$pokefetchCommandLine = (Get-CimInstance Win32_Process -Filter "ProcessId=$PID").CommandLine
$pokefetchInteractive = $pokefetchCommandLine -notmatch '(?i)\s-(command|c|file|f|encodedcommand|enc|noninteractive)\b'
if ($pokefetchInteractive) {
    Invoke-PokeFetch
}

if (Test-Path Alias:cls) {
    Remove-Item Alias:cls -Force
}
function global:cls {
    Clear-Host
    pokefetch --from-cls --shell-name "PowerShell $($PSVersionTable.PSVersion)" show
}
'@

    if (-not (Test-Path -LiteralPath (Split-Path -Parent $PowerShellProfile))) {
        New-Item -ItemType Directory -Path (Split-Path -Parent $PowerShellProfile) | Out-Null
    }

    $profileText = if (Test-Path -LiteralPath $PowerShellProfile) { Get-Content -LiteralPath $PowerShellProfile -Raw } else { '' }
    $profileText = [regex]::Replace($profileText, '(?s)\r?\n?# >>> pokefetch >>>.*?# <<< pokefetch <<<\r?\n?', '')
    Set-Content -LiteralPath $PowerShellProfile -Value ($profileText.TrimEnd() + "`n`n# >>> pokefetch >>>`n$psBlock`n# <<< pokefetch <<<`n") -Encoding UTF8

    Set-Content -LiteralPath $CmdAutorun -Encoding ASCII -Value @'
@echo off
if "%POKEFETCH_DISABLE%"=="1" exit /b 0
setlocal EnableDelayedExpansion
set "_cmd=!CMDCMDLINE!"
if not "!_cmd:/c =!"=="!_cmd!" exit /b 0
if not "!_cmd:/C =!"=="!_cmd!" exit /b 0
if not "!_cmd: /c=!"=="!_cmd!" exit /b 0
if not "!_cmd: /C=!"=="!_cmd!" exit /b 0
endlocal
chcp 65001 >nul
doskey cls=cmd /c cls $T pokefetch --from-cls --shell-name CMD show
pokefetch --shell-name CMD show
'@

    $registryPath = 'HKCU:\Software\Microsoft\Command Processor'
    if (-not (Test-Path -LiteralPath $registryPath)) {
        New-Item -Path $registryPath -Force | Out-Null
    }
    $existingAutorun = (Get-ItemProperty -Path $registryPath -Name AutoRun -ErrorAction SilentlyContinue).AutoRun
    $call = 'call "' + $CmdAutorun + '"'
    $clinkCall = '"C:\Program Files (x86)\clink\clink.bat" inject --autorun'
    $existingAutorun = [regex]::Replace($existingAutorun, 'call "[^"]*PokeFetch\\cmd-autorun\.cmd"&?', '', 'IgnoreCase')
    $existingAutorun = [regex]::Replace($existingAutorun, '"?C:\\Program Files \(x86\)\\clink\\clink\.bat"? inject --autorun(?: --profile [^&]+)?&?', '', 'IgnoreCase')
    $newAutorun = $call
    if (Test-Path -LiteralPath 'C:\Program Files (x86)\clink\clink.bat') {
        $newAutorun = $newAutorun + '&' + $clinkCall
    }
    if ($existingAutorun) {
        $existingAutorun = $existingAutorun.Trim('&')
        if ($existingAutorun) {
            $newAutorun = $newAutorun + '&' + $existingAutorun
        }
    }
    Set-ItemProperty -Path $registryPath -Name AutoRun -Value $newAutorun
}

"PokeFetch installed. Config: $ConfigPath"
