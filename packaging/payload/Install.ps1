#Requires -Version 5.1
<#
.SYNOPSIS
  Post-install: NSSM service LlamaCppKortex + single PowerShell tray autostart.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$InstallDir,
    [switch]$Unattended
)

$ErrorActionPreference = "Stop"
$log = Join-Path $env:TEMP "LlamaCppKortexio-Install.log"
function L([string]$m) {
    $line = "[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $m
    Add-Content -Path $log -Value $line
    Write-Host $line
}

try {
    "" | Set-Content $log
    L "InstallDir=$InstallDir"
    $bin = Join-Path $InstallDir "bin"
    $scripts = Join-Path $InstallDir "scripts"
    $runBat = Join-Path $scripts "run-server.bat"
    $logDir = Join-Path $InstallDir "logs"
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null

    if (-not (Test-Path (Join-Path $bin "llama-server.exe"))) {
        throw "llama-server.exe missing in $bin"
    }
    if (-not (Test-Path $runBat)) {
        throw "run-server.bat missing: $runBat"
    }

    $nssm = (Get-Command nssm.exe -ErrorAction SilentlyContinue).Source
    if (-not $nssm) { $nssm = "$env:LOCALAPPDATA\Microsoft\WinGet\Links\nssm.exe" }
    if (-not (Test-Path $nssm)) {
        L "NSSM missing — trying winget install"
        try {
            winget install --id NSSM.NSSM -e --accept-package-agreements --accept-source-agreements | Out-Null
        } catch {}
        $nssm = (Get-Command nssm.exe -ErrorAction SilentlyContinue).Source
        if (-not $nssm) { $nssm = "$env:LOCALAPPDATA\Microsoft\WinGet\Links\nssm.exe" }
    }
    if (-not (Test-Path $nssm)) {
        throw "nssm.exe not found. Install via: winget install NSSM.NSSM"
    }
    L "nssm=$nssm"

    # Stop legacy Tray.exe so we never end with two icons
    Get-Process "LlamaCpp.Tray" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

    $name = "LlamaCppKortex"
    if (Get-Service -Name $name -ErrorAction SilentlyContinue) {
        cmd /c "`"$nssm`" stop $name confirm" | Out-Null
        Start-Sleep 2
        cmd /c "`"$nssm`" remove $name confirm" | Out-Null
        Start-Sleep 1
    }

    & $nssm install $name $runBat
    & $nssm set $name AppDirectory $bin
    & $nssm set $name DisplayName "LlamaCppKortexio Server"
    & $nssm set $name Description "llama-server WebUI/API on 127.0.0.1:11434 (Kortexio build)"
    & $nssm set $name Start SERVICE_DELAYED_AUTO_START
    & $nssm set $name AppStdout (Join-Path $logDir "llama-server.svc.out.log")
    & $nssm set $name AppStderr (Join-Path $logDir "llama-server.svc.err.log")
    & $nssm set $name AppRotateFiles 1
    & $nssm set $name AppRotateBytes 1048576
    & $nssm set $name AppRestartDelay 5000
    sc.exe config $name start= delayed-auto | Out-Null
    L "service configured"

    & $nssm start $name
    Start-Sleep 3
    $svc = Get-Service $name
    L "service status=$($svc.Status)"

    # Single tray: PowerShell Kortex tray (includes Settings). Not LlamaCpp.Tray.exe.
    $trayBat = Join-Path $InstallDir "Start-KortexTray.bat"
    $trayVbs = Join-Path $InstallDir "tray\Start-LlamaTray.vbs"
    $trayLaunch = if (Test-Path $trayBat) { $trayBat } elseif (Test-Path $trayVbs) { $trayVbs } else { $null }

    if ($trayLaunch) {
        $runKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
        New-Item -Path $runKey -Force | Out-Null
        Set-ItemProperty -Path $runKey -Name "LlamaCppTray" -Value "`"$trayLaunch`"" -Type String
        L "tray Run key set -> $trayLaunch"

        $taskName = "LlamaCppTrayLogon"
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
        $action = New-ScheduledTaskAction -Execute $trayLaunch -WorkingDirectory $InstallDir
        $trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
        Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Force | Out-Null
        L "scheduled task $taskName registered"

        $startup = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\Startup"
        Get-ChildItem $startup -Filter "*Kortex*Tray*" -EA SilentlyContinue | Remove-Item -Force -EA SilentlyContinue
        Get-ChildItem $startup -Filter "*Llama.cpp*Tray*" -EA SilentlyContinue | Remove-Item -Force -EA SilentlyContinue

        Start-Process -FilePath $trayLaunch -WorkingDirectory $InstallDir
        L "tray launched (single entrypoint)"
    } else {
        L "WARN: no tray launcher found"
    }

    L "OK"
    if (-not $Unattended) {
        Start-Process "http://127.0.0.1:11434/"
    }
    exit 0
}
catch {
    L "ERROR: $_"
    L $_.ScriptStackTrace
    exit 1
}
