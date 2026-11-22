; Inno Setup — установщик Arij для Windows.
; Собирается в CI: iscc arij.iss /DMyAppVersion=<версия> /DSourceDir=<папка Release> /DOutputDir=dist

#ifndef MyAppVersion
  #define MyAppVersion "2.0.0"
#endif
#ifndef SourceDir
  #define SourceDir "build\windows\x64\runner\Release"
#endif
#ifndef OutputDir
  #define OutputDir "dist"
#endif

#define MyAppName "Arij"
#define MyAppExeName "task_tracker_oridj.exe"

[Setup]
AppId={{8F3B2C1A-7D4E-4B6A-9C1F-2E5A7D9B0C3E}}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher=Arij
DefaultDirName={localappdata}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
; Обновление поверх уже установленной версии: закрываем приложение и
; перезапускаем его после установки (можно также передать флаги
; /CLOSEAPPLICATIONS /RESTARTAPPLICATIONS из автообновления).
CloseApplications=yes
RestartApplications=yes
OutputDir={#OutputDir}
OutputBaseFilename=ArijSetup-{#MyAppVersion}-x64
SetupIconFile=..\..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
Name: "russian"; MessagesFile: "compiler:Languages\Russian.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,Arij}"; Flags: nowait postinstall skipifsilent
