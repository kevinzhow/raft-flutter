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
#ifndef RuntimeInstaller
  #error RuntimeInstaller is required
#endif
#ifndef RuntimeCheckArguments
  #error RuntimeCheckArguments is required
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
; Extract only when needed; it is not a DLL or part of the portable bundle.
Source: "{#RuntimeInstaller}"; DestName: "WindowsAppRuntimeInstall-x64.exe"; Flags: dontcopy

[Icons]
Name: "{autoprograms}\Raft"; Filename: "{app}\raft_flutter.exe"

[Run]
; Runs after silent updates too (no skipifsilent), which relaunches the app that
; WinSparkle closed before starting this installer.
Filename: "{app}\raft_flutter.exe"; Description: "Launch Raft"; Flags: nowait postinstall

[Code]
function WindowsAppRuntimePresent: Boolean;
var
  CheckExitCode: Integer;
begin
  Result := Exec(ExpandConstant('{sys}\WindowsPowerShell\v1.0\powershell.exe'),
    '{#RuntimeCheckArguments}', '', SW_HIDE, ewWaitUntilTerminated, CheckExitCode);
  Result := Result and (CheckExitCode = 0);
  Log(Format('Windows App Runtime 1.7 check: present=%d, status=%d', [Ord(Result), CheckExitCode]));
end;

procedure InstallWindowsAppRuntime;
var
  InstallExitCode: Integer;
  Started: Boolean;
  Retry: Boolean;
begin
  if WindowsAppRuntimePresent then
    Exit;
  ExtractTemporaryFile('WindowsAppRuntimeInstall-x64.exe');
  repeat
    WizardForm.StatusLabel.Caption := 'Installing Windows notification support...';
    { No elevation, --force, or shutdown of other applications. }
    Started := Exec(ExpandConstant('{tmp}\WindowsAppRuntimeInstall-x64.exe'),
      '--quiet', '', SW_HIDE, ewWaitUntilTerminated, InstallExitCode);
    Log(Format('Windows App Runtime installer: started=%d, status=%d', [Ord(Started), InstallExitCode]));
    if Started and ((InstallExitCode = 0) or (InstallExitCode = 3010)) and
       WindowsAppRuntimePresent then
      Exit;
    { Notifications are optional: a dependency failure must not prevent Raft opening. }
    Retry := SuppressibleMsgBox(
      'Windows notification support could not be installed (status ' + IntToStr(InstallExitCode) + ').' + #13#10#13#10 +
      'Retry now? Choose No to finish installing Raft without Windows notifications. You can run this installer again to retry.',
      mbError, MB_YESNO, IDNO) = IDYES;
  until not Retry;
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
    InstallWindowsAppRuntime;
end;
