!include "MUI2.nsh"
!include "LogicLib.nsh"

!ifndef PRODUCT_NAME
  !define PRODUCT_NAME "VI History Suite"
!endif

!ifndef PRODUCT_VERSION
  !define PRODUCT_VERSION "0.0.0"
!endif

!ifndef EXTENSION_IDENTIFIER
  !define EXTENSION_IDENTIFIER "svelderrainruiz.vi-history-suite"
!endif

!ifndef STAGING_ROOT
  !define STAGING_ROOT "."
!endif

!ifndef OUTPUT_FILE
  !define OUTPUT_FILE "vi-history-suite-setup.exe"
!endif

!ifndef VSCODE_BOOTSTRAP_FILE
  !define VSCODE_BOOTSTRAP_FILE "VSCodeSetup-x64.exe"
!endif

!ifndef GIT_BOOTSTRAP_FILE
  !define GIT_BOOTSTRAP_FILE "Git-64-bit.exe"
!endif

!ifndef DOCKER_DESKTOP_BOOTSTRAP_FILE
  !define DOCKER_DESKTOP_BOOTSTRAP_FILE "Docker Desktop Installer.exe"
!endif

!ifndef HARNESS_BOOTSTRAP_SCRIPT_FILE
  !define HARNESS_BOOTSTRAP_SCRIPT_FILE "Invoke-HarnessBootstrap.ps1"
!endif

!define UNINSTALL_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PRODUCT_NAME}"

Unicode True
Name "${PRODUCT_NAME}"
OutFile "${OUTPUT_FILE}"
InstallDir "$LOCALAPPDATA\Programs\VI History Suite"
InstallDirRegKey HKCU "${UNINSTALL_KEY}" "InstallLocation"
RequestExecutionLevel admin
ShowInstDetails show
ShowUninstDetails show

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "English"

Var CodeCommand
Var GitCommand

Function ResolveCodeCommand
  StrCpy $CodeCommand ""

  IfFileExists "$LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd" 0 +2
    StrCpy $CodeCommand "$LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd"

  ${If} $CodeCommand == ""
    IfFileExists "$PROGRAMFILES\Microsoft VS Code\bin\code.cmd" 0 +2
      StrCpy $CodeCommand "$PROGRAMFILES\Microsoft VS Code\bin\code.cmd"
  ${EndIf}

  ${If} $CodeCommand == ""
    IfFileExists "$PROGRAMFILES64\Microsoft VS Code\bin\code.cmd" 0 +2
      StrCpy $CodeCommand "$PROGRAMFILES64\Microsoft VS Code\bin\code.cmd"
  ${EndIf}

  ${If} $CodeCommand == ""
    IfFileExists "$LOCALAPPDATA\Programs\Microsoft VS Code\Code.exe" 0 +2
      StrCpy $CodeCommand "$LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd"
  ${EndIf}
FunctionEnd

Function ResolveGitCommand
  StrCpy $GitCommand ""

  IfFileExists "$LOCALAPPDATA\Programs\Git\cmd\git.exe" 0 +2
    StrCpy $GitCommand "$LOCALAPPDATA\Programs\Git\cmd\git.exe"

  ${If} $GitCommand == ""
    IfFileExists "$PROGRAMFILES\Git\cmd\git.exe" 0 +2
      StrCpy $GitCommand "$PROGRAMFILES\Git\cmd\git.exe"
  ${EndIf}

  ${If} $GitCommand == ""
    IfFileExists "$PROGRAMFILES64\Git\cmd\git.exe" 0 +2
      StrCpy $GitCommand "$PROGRAMFILES64\Git\cmd\git.exe"
  ${EndIf}

  ${If} $GitCommand == ""
    IfFileExists "$LOCALAPPDATA\Programs\Git\bin\git.exe" 0 +2
      StrCpy $GitCommand "$LOCALAPPDATA\Programs\Git\bin\git.exe"
  ${EndIf}
FunctionEnd

Function un.ResolveCodeCommand
  StrCpy $CodeCommand ""

  IfFileExists "$LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd" 0 +2
    StrCpy $CodeCommand "$LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd"

  ${If} $CodeCommand == ""
    IfFileExists "$PROGRAMFILES\Microsoft VS Code\bin\code.cmd" 0 +2
      StrCpy $CodeCommand "$PROGRAMFILES\Microsoft VS Code\bin\code.cmd"
  ${EndIf}

  ${If} $CodeCommand == ""
    IfFileExists "$PROGRAMFILES64\Microsoft VS Code\bin\code.cmd" 0 +2
      StrCpy $CodeCommand "$PROGRAMFILES64\Microsoft VS Code\bin\code.cmd"
  ${EndIf}

  ${If} $CodeCommand == ""
    IfFileExists "$LOCALAPPDATA\Programs\Microsoft VS Code\Code.exe" 0 +2
      StrCpy $CodeCommand "$LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd"
  ${EndIf}
FunctionEnd

Function EnsureVisualStudioCode
  Call ResolveCodeCommand
  ${If} $CodeCommand == ""
    IfFileExists "$INSTDIR\bootstrap\vscode\${VSCODE_BOOTSTRAP_FILE}" 0 missing_vscode_bootstrap
    DetailPrint "Installing Visual Studio Code from the pinned bootstrap installer."
    ExecWait '"$INSTDIR\bootstrap\vscode\${VSCODE_BOOTSTRAP_FILE}" /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /MERGETASKS=!runcode' $0
    ${If} $0 != 0
      Push "Visual Studio Code bootstrap failed. Exit code: $0"
      Call FailInstall
    ${EndIf}

    Call ResolveCodeCommand
    ${If} $CodeCommand == ""
      Push "Visual Studio Code CLI was not found after bootstrap. The install cannot continue."
      Call FailInstall
    ${EndIf}
  ${EndIf}
  Return

missing_vscode_bootstrap:
  Push "Visual Studio Code bootstrap installer was not staged with this build."
  Call FailInstall
FunctionEnd

Function EnsureGit
  Call ResolveGitCommand
  ${If} $GitCommand == ""
    IfFileExists "$INSTDIR\bootstrap\git\${GIT_BOOTSTRAP_FILE}" 0 missing_git_bootstrap
    DetailPrint "Installing Git for Windows from the pinned bootstrap installer."
    ExecWait '"$INSTDIR\bootstrap\git\${GIT_BOOTSTRAP_FILE}" /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP-' $0
    ${If} $0 != 0
      Push "Git bootstrap failed. Exit code: $0"
      Call FailInstall
    ${EndIf}

    Call ResolveGitCommand
    ${If} $GitCommand == ""
      Push "Git executable was not found after bootstrap. The install cannot continue."
      Call FailInstall
    ${EndIf}
  ${EndIf}
  Return

missing_git_bootstrap:
  Push "Git bootstrap installer was not staged with this build."
  Call FailInstall
FunctionEnd

Function FailInstall
  Pop $0
  RMDir /r "$INSTDIR"
  MessageBox MB_ICONSTOP|MB_OK "$0"
  Abort
FunctionEnd

Function FailInstallPreserveInstallRoot
  Pop $0
  MessageBox MB_ICONEXCLAMATION|MB_OK "$0"
  Abort
FunctionEnd

Function RunHarnessBootstrap
  IfFileExists "$INSTDIR\scripts\${HARNESS_BOOTSTRAP_SCRIPT_FILE}" 0 missing_harness_bootstrap
  DetailPrint "Preparing the pinned proof workspace and Docker Desktop harness prerequisites."
  ExecWait '"$SYSDIR\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "$INSTDIR\scripts\${HARNESS_BOOTSTRAP_SCRIPT_FILE}" -InstallRoot "$INSTDIR" -ReleaseContractPath "$INSTDIR\contracts\release-ingestion.json" -FixtureManifestPath "$INSTDIR\fixtures\labview-icon-editor.manifest.json" -GitCommand "$GitCommand"' $0
  ${If} $0 == 3010
    Push "Docker Desktop requested a Windows restart before the harness could finish. Restart Windows and rerun this installer to complete the pinned Windows container image preparation."
    Call FailInstallPreserveInstallRoot
  ${EndIf}
  ${If} $0 == 1641
    Push "Docker Desktop triggered a restart request before the harness could finish. Restart Windows and rerun this installer to complete the pinned Windows container image preparation."
    Call FailInstallPreserveInstallRoot
  ${EndIf}
  ${If} $0 != 0
    Push "Harness bootstrap failed. See $INSTDIR\logs for the retained proof-workspace and Docker preparation logs. Exit code: $0"
    Call FailInstall
  ${EndIf}
  Return

missing_harness_bootstrap:
  Push "Harness bootstrap script was not staged with this build."
  Call FailInstall
FunctionEnd

Function InstallExtensionWithCode
  Call EnsureVisualStudioCode
  Call EnsureGit
  Call RunHarnessBootstrap

  DetailPrint "Installing ${EXTENSION_IDENTIFIER} from the immutable staged VSIX."
  ExecWait '"$CodeCommand" --install-extension "$INSTDIR\payload\vi-history-suite-${PRODUCT_VERSION}.vsix" --force' $0
  ${If} $0 != 0
    Push "VS Code failed to install ${EXTENSION_IDENTIFIER}. Exit code: $0"
    Call FailInstall
  ${EndIf}
FunctionEnd

Section "Install"
  SetOutPath "$INSTDIR"
  File /r "${STAGING_ROOT}\*"
  DetailPrint "Retaining contracts\release-ingestion.json with the installed public support materials."

  Call InstallExtensionWithCode

  WriteUninstaller "$INSTDIR\Uninstall VI History Suite.exe"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayName" "${PRODUCT_NAME}"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayVersion" "${PRODUCT_VERSION}"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "Publisher" "svelderrainruiz"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "InstallLocation" "$INSTDIR"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "UninstallString" '"$INSTDIR\Uninstall VI History Suite.exe"'
  WriteRegStr HKCU "${UNINSTALL_KEY}" "QuietUninstallString" '"$INSTDIR\Uninstall VI History Suite.exe" /S'
  WriteRegDWORD HKCU "${UNINSTALL_KEY}" "NoModify" 1
  WriteRegDWORD HKCU "${UNINSTALL_KEY}" "NoRepair" 1
SectionEnd

Section "Uninstall"
  Call un.ResolveCodeCommand
  ${If} $CodeCommand != ""
    DetailPrint "Removing ${EXTENSION_IDENTIFIER} from Visual Studio Code."
    ExecWait '"$CodeCommand" --uninstall-extension "${EXTENSION_IDENTIFIER}"' $0
  ${EndIf}

  DetailPrint "Leaving shared Visual Studio Code, Git, and Docker Desktop installations untouched."
  Delete "$INSTDIR\Uninstall VI History Suite.exe"
  RMDir /r "$INSTDIR"
  DeleteRegKey HKCU "${UNINSTALL_KEY}"
SectionEnd
