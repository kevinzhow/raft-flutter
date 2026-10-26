; Inno Setup script for the Raft per-user installer, the only archive form
; WinSparkle can run. Compiled by tool/windows_installer.py, which supplies:
;   /DSourceDir=<staged bundle>  /DOutputDir=<dir>  /DOutputName=<file stem>
;   /DAppVersion=<x.y.z[-pre]>   /DNumericVersion=<x.y.z.build>
; Per-user install (no administrator prompt) so silent updates need no UAC.
; unins000.exe next to raft_flutter.exe is how the app recognises an installed
; build (portable ZIP builds never auto-update; see docs/auto-update.md).

#ifndef SourceDir
  #error SourceDir is required
#endif
#ifndef AppVersion
  #error AppVersion is required
#endif

[Setup]
; Never change AppId: it links every future update to the same installation.
AppId={{9A4A1E4B-DA33-4784-95CA-15E0D360C3B2}
AppName=Raft
AppVersion={#AppVersion}
AppPublisher=app.raft
DefaultDirName={autopf}\Raft
DefaultGroupName=Raft
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir={#OutputDir}
OutputBaseFilename={#OutputName}
VersionInfoVersion={#NumericVersion}
VersionInfoProductName=Raft
SetupIconFile={#SourceDir}\raft.ico
UninstallDisplayIcon={app}\raft_flutter.exe
Compression=lzma2
SolidCompression=yes
CloseApplications=yes
RestartApplications=no
DisableProgramGroupPage=yes
WizardStyle=modern

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion

[Icons]
Name: "{autoprograms}\Raft"; Filename: "{app}\raft_flutter.exe"; AppUserModelID: "app.raft.raft_flutter"

[Run]
; Runs after silent updates too (no skipifsilent), which relaunches the app that
; WinSparkle closed before starting this installer.
Filename: "{app}\raft_flutter.exe"; Description: "Launch Raft"; Flags: nowait postinstall
