Set sh = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
dir = fso.GetParentFolderName(WScript.ScriptFullName)
ps1 = dir & "\LlamaTray.ps1"
' Single-instance: quit if another Kortex tray PowerShell is already hosting LlamaTray.ps1
sh.Run "powershell.exe -NoProfile -WindowStyle Hidden -STA -ExecutionPolicy Bypass -File """ & ps1 & """", 0, False
