Set sh = CreateObject("WScript.Shell")
dir = CreateObject("Scripting.FileSystemObject").GetParentFolderName(WScript.ScriptFullName)
ps1 = dir & "\LlamaTray.ps1"
sh.Run "powershell.exe -NoProfile -WindowStyle Hidden -STA -ExecutionPolicy Bypass -File """ & ps1 & """", 0, False
