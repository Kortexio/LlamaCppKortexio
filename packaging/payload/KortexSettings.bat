@echo off
start "" powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0tray\KortexSettings.ps1"
