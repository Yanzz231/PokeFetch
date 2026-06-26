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

py -m pip install --user -e $Root

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
    } | ConvertTo-Json -Depth 4
    Set-Content -LiteralPath $ConfigPath -Value ($config + "`n") -Encoding UTF8
}

if (-not $SkipShellHooks) {
    $psBlock = @'
$pokefetchCommandLine = (Get-CimInstance Win32_Process -Filter "ProcessId=$PID").CommandLine
$pokefetchInteractive = $pokefetchCommandLine -notmatch '(?i)\s-(command|c|file|f|encodedcommand|enc|noninteractive)\b'
if ($pokefetchInteractive -and $env:POKEFETCH_DISABLE -ne '1') {
    py -m src --shell-name "PowerShell $($PSVersionTable.PSVersion)"
}
'@

    if (-not (Test-Path -LiteralPath (Split-Path -Parent $PowerShellProfile))) {
        New-Item -ItemType Directory -Path (Split-Path -Parent $PowerShellProfile) | Out-Null
    }

    $profileText = if (Test-Path -LiteralPath $PowerShellProfile) { Get-Content -LiteralPath $PowerShellProfile -Raw } else { '' }
    if ($profileText -notmatch '# >>> pokefetch >>>') {
        Add-Content -LiteralPath $PowerShellProfile -Value "`n# >>> pokefetch >>>`n$psBlock`n# <<< pokefetch <<<`n" -Encoding UTF8
    }

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
py -m src --shell-name CMD
'@

    $registryPath = 'HKCU:\Software\Microsoft\Command Processor'
    if (-not (Test-Path -LiteralPath $registryPath)) {
        New-Item -Path $registryPath -Force | Out-Null
    }
    $existingAutorun = (Get-ItemProperty -Path $registryPath -Name AutoRun -ErrorAction SilentlyContinue).AutoRun
    $call = 'call "' + $CmdAutorun + '"'
    if (-not $existingAutorun) {
        Set-ItemProperty -Path $registryPath -Name AutoRun -Value $call
    } elseif ($existingAutorun -notlike "*$CmdAutorun*") {
        Set-ItemProperty -Path $registryPath -Name AutoRun -Value ($call + '&' + $existingAutorun)
    }
}

"PokeFetch installed. Config: $ConfigPath"
