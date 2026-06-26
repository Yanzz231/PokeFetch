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
$ScriptsPath = py -c "import sysconfig; print(sysconfig.get_path('scripts', scheme='nt_user'))"
$UserPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if ($UserPath -notlike "*$ScriptsPath*") {
    [Environment]::SetEnvironmentVariable('Path', ($UserPath.TrimEnd(';') + ';' + $ScriptsPath), 'User')
}
if ($env:Path -notlike "*$ScriptsPath*") {
    $env:Path = $env:Path + ';' + $ScriptsPath
}

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

if (-not $SkipShellHooks) {
    $psBlock = @'
function Invoke-PokeFetch {
    if ($env:POKEFETCH_DISABLE -ne '1') {
        pokefetch --shell-name "PowerShell $($PSVersionTable.PSVersion)"
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
    pokefetch --from-cls --shell-name "PowerShell $($PSVersionTable.PSVersion)"
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
doskey cls=cmd /c cls $T pokefetch --from-cls --shell-name CMD
pokefetch --shell-name CMD
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
