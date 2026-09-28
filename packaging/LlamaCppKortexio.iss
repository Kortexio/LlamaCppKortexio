; LlamaCppKortexio Windows installer
; Bundles: llama-server (embedded WebUI) + CUDA runtime DLLs + tray + NSSM post-install

#define MyAppName "LlamaCppKortexio"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Kortexio"
#define MyAppURL "https://github.com/Kortexio/LlamaCppKortexio"
#define MyAppExeName "LlamaCpp.Tray.exe"

[Setup]
AppId={{A8F3C2E1-9B47-4D6A-8E12-7B6C5D4E3F2A}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}/issues
DefaultDirName={autopf}\LlamaCppKortexio
DefaultGroupName=LlamaCppKortexio
DisableProgramGroupPage=yes
LicenseFile=
OutputDir=output
OutputBaseFilename=LlamaCppKortexio-Setup-{#MyAppVersion}
SetupIconFile=payload\llamacpp.ico
UninstallDisplayIcon={app}\llamacpp.ico
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
InfoBeforeFile=INFO_BEFORE.txt
InfoAfterFile=INFO_AFTER.txt

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "portuguese"; MessagesFile: "compiler:Languages\Portuguese.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "autostart_tray"; Description: "Start tray icon at Windows logon"; GroupDescription: "Startup"; Flags: checkedonce
Name: "start_service"; Description: "Install and start LlamaCppKortex Windows service (NSSM)"; GroupDescription: "Service"; Flags: checkedonce

[Files]
; Core runtime (llama-server embeds WebUI)
Source: "payload\bin\*"; DestDir: "{app}\bin"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "payload\scripts\*"; DestDir: "{app}\scripts"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "payload\config\*"; DestDir: "{app}\config"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "payload\tray\*"; DestDir: "{app}\tray"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "payload\LlamaCpp.Tray.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "payload\llamacpp.ico"; DestDir: "{app}"; Flags: ignoreversion
Source: "payload\Install.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "payload\Uninstall.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "payload\KortexSettings.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "payload\KortexSettings.bat"; DestDir: "{app}"; Flags: ignoreversion
Source: "payload\README-INSTALL.txt"; DestDir: "{app}"; Flags: ignoreversion isreadme

[Icons]
Name: "{group}\{#MyAppName} Tray"; Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"
Name: "{group}\Kortex Settings"; Filename: "{app}\KortexSettings.bat"; WorkingDir: "{app}"
Name: "{group}\Open WebUI"; Filename: "http://127.0.0.1:11434/"
Name: "{group}\Uninstall {#MyAppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"; Tasks: desktopicon

[Run]
; Post-install: NSSM service + tray (requires admin; nssm via winget if missing)
Filename: "powershell.exe"; \
  Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\Install.ps1"" -InstallDir ""{app}"" -Unattended"; \
  StatusMsg: "Configuring Windows service and tray..."; \
  Flags: runhidden waituntilterminated; \
  Tasks: start_service
Filename: "{app}\{#MyAppExeName}"; Description: "Launch tray icon"; Flags: nowait postinstall skipifsilent; \
  Check: not WizardIsTaskSelected('start_service')
Filename: "http://127.0.0.1:11434/"; Description: "Open WebUI"; Flags: postinstall shellexec skipifsilent unchecked

[UninstallRun]
Filename: "powershell.exe"; \
  Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\Uninstall.ps1"" -InstallDir ""{app}"""; \
  RunOnceId: "KortexUninstallCleanup"; Flags: runhidden waituntilterminated

[Code]
function InitializeSetup(): Boolean;
begin
  Result := True;
end;

