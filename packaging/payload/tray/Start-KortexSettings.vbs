Set fso = CreateObject("Scripting.FileSystemObject")
dir = fso.GetParentFolderName(WScript.ScriptFullName)
ps1 = dir & "\KortexSettings.ps1"
If Not fso.FileExists(ps1) Then ps1 = dir & "\tray\KortexSettings.ps1"
If Not fso.FileExists(ps1) Then
  MsgBox "KortexSettings.ps1 not found.", 16, "Kortexio"
  WScript.Quit 1
End If

' Launch PowerShell with ShowWindow=SW_HIDE (no console flash)
Const SW_HIDE = 0
cmd = "powershell.exe -NoProfile -NoLogo -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & ps1 & """"
Set wmi = GetObject("winmgmts:\\.\root\cimv2")
Set startup = wmi.Get("Win32_ProcessStartup").SpawnInstance_()
startup.ShowWindow = SW_HIDE
Set proc = GetObject("winmgmts:\\.\root\cimv2:Win32_Process")
rc = proc.Create(cmd, Null, startup, pid)
If rc <> 0 Then
  ' Fallback: WScript.Shell hidden
  CreateObject("WScript.Shell").Run cmd, 0, False
End If
