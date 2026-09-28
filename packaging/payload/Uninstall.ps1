#Requires -Version 5.1
param(
    [Parameter(Mandatory = $true)]
    [string]$InstallDir
)
$ErrorActionPreference = "Continue"
$nssm = (Get-Command nssm.exe -EA SilentlyContinue).Source
if (-not $nssm) { $nssm = "$env:LOCALAPPDATA\Microsoft\WinGet\Links\nssm.exe" }

$name = "LlamaCppKortex"
if ($nssm -and (Get-Service $name -EA SilentlyContinue)) {
    & $nssm stop $name confirm 2>$null
    Start-Sleep 2
    & $nssm remove $name confirm 2>$null
}
Get-Process llama-server, "LlamaCpp.Tray" -EA SilentlyContinue | Stop-Process -Force -EA SilentlyContinue
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -EA SilentlyContinue |
  Where-Object { $_.CommandLine -match 'LlamaTray\.ps1' } |
  ForEach-Object { Stop-Process -Id $_.ProcessId -Force -EA SilentlyContinue }

Unregister-ScheduledTask -TaskName "LlamaCppTrayLogon" -Confirm:$false -EA SilentlyContinue
Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "LlamaCppTray" -EA SilentlyContinue
$startup = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\Startup"
Get-ChildItem $startup -Filter "*Kortex*Tray*" -EA SilentlyContinue | Remove-Item -Force -EA SilentlyContinue
Get-ChildItem $startup -Filter "*Llama.cpp*Tray*" -EA SilentlyContinue | Remove-Item -Force -EA SilentlyContinue

Write-Host "LlamaCppKortexio uninstalled (service/tray). Files under $InstallDir removed by Setup."
