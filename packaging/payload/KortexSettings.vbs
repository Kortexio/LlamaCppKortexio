' Kortex Settings launcher (no .bat / no console)
Set fso = CreateObject("Scripting.FileSystemObject")
dir = fso.GetParentFolderName(WScript.ScriptFullName)
vbs = dir & "\tray\Start-KortexSettings.vbs"
If fso.FileExists(vbs) Then
  CreateObject("WScript.Shell").Run "wscript.exe //nologo """ & vbs & """", 0, False
Else
  CreateObject("WScript.Shell").Run "wscript.exe //nologo """ & dir & "\Start-KortexSettings.vbs""", 0, False
End If
