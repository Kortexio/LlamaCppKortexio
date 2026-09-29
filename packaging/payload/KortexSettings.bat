@echo off
REM Thin wrapper — prefer KortexSettings.vbs to avoid console flash
wscript.exe //nologo "%~dp0KortexSettings.vbs"
