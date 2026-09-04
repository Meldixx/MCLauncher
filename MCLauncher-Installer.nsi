Unicode true
!include "MUI2.nsh"
!include "x64.nsh"

!ifndef APP_VERSION
  !define APP_VERSION "1.0.0"
!endif
!ifndef SOURCE_DIR
  !error "SOURCE_DIR is required"
!endif
!ifndef OUT_FILE
  !define OUT_FILE "MCLauncher-v${APP_VERSION}.exe"
!endif
!ifndef APP_ICON
  !define APP_ICON "mclauncher.ico"
!endif

!define APP_NAME "MCLauncher"
!define APP_PUBLISHER "TrioSoft"
!define APP_WEBSITE "https://triosoft.xyz"
!define APP_EXE "mclauncher.exe"
!define UNINSTALL_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\MCLauncher"

Name "${APP_NAME} ${APP_VERSION}"
OutFile "${OUT_FILE}"
InstallDir "$PROGRAMFILES64\MCLauncher"
InstallDirRegKey HKLM "${UNINSTALL_KEY}" "InstallLocation"
RequestExecutionLevel admin
SetCompressor /SOLID lzma
SetRegView 64
Icon "${APP_ICON}"
UninstallIcon "${APP_ICON}"
BrandingText "MCLauncher by TrioSoft · triosoft.xyz"

VIProductVersion "1.0.0.0"
VIAddVersionKey /LANG=1049 "ProductName" "MCLauncher"
VIAddVersionKey /LANG=1049 "ProductVersion" "${APP_VERSION}"
VIAddVersionKey /LANG=1049 "CompanyName" "TrioSoft"
VIAddVersionKey /LANG=1049 "FileDescription" "MCLauncher Setup"
VIAddVersionKey /LANG=1049 "LegalCopyright" "Copyright © 2026 TrioSoft / MELDIX"

!define MUI_ICON "${APP_ICON}"
!define MUI_UNICON "${APP_ICON}"
!define MUI_ABORTWARNING
!define MUI_FINISHPAGE_RUN "$INSTDIR\${APP_EXE}"
!define MUI_FINISHPAGE_LINK "Открыть сайт TrioSoft"
!define MUI_FINISHPAGE_LINK_LOCATION "${APP_WEBSITE}"

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "Russian"
!insertmacro MUI_LANGUAGE "English"

Section "MCLauncher" SEC_MAIN
  SectionIn RO
  SetOutPath "$INSTDIR"
  File /r "${SOURCE_DIR}\*.*"

  WriteUninstaller "$INSTDIR\Uninstall.exe"

  CreateDirectory "$SMPROGRAMS\MCLauncher"
  CreateShortcut "$SMPROGRAMS\MCLauncher\MCLauncher.lnk" "$INSTDIR\${APP_EXE}" "" "$INSTDIR\${APP_EXE}" 0
  CreateShortcut "$SMPROGRAMS\MCLauncher\Удалить MCLauncher.lnk" "$INSTDIR\Uninstall.exe"
  CreateShortcut "$DESKTOP\MCLauncher.lnk" "$INSTDIR\${APP_EXE}" "" "$INSTDIR\${APP_EXE}" 0

  ; Deep links used by triosoft.xyz: mclauncher://install/<slug>
  WriteRegStr HKCR "mclauncher" "" "URL:MCLauncher Protocol"
  WriteRegStr HKCR "mclauncher" "URL Protocol" ""
  WriteRegStr HKCR "mclauncher\DefaultIcon" "" "$INSTDIR\${APP_EXE},0"
  WriteRegStr HKCR "mclauncher\shell\open\command" "" '"$INSTDIR\${APP_EXE}" "%1"'

  WriteRegStr HKLM "${UNINSTALL_KEY}" "DisplayName" "MCLauncher ${APP_VERSION}"
  WriteRegStr HKLM "${UNINSTALL_KEY}" "DisplayVersion" "${APP_VERSION}"
  WriteRegStr HKLM "${UNINSTALL_KEY}" "Publisher" "TrioSoft"
  WriteRegStr HKLM "${UNINSTALL_KEY}" "URLInfoAbout" "${APP_WEBSITE}"
  WriteRegStr HKLM "${UNINSTALL_KEY}" "HelpLink" "${APP_WEBSITE}/help"
  WriteRegStr HKLM "${UNINSTALL_KEY}" "InstallLocation" "$INSTDIR"
  WriteRegStr HKLM "${UNINSTALL_KEY}" "DisplayIcon" "$INSTDIR\${APP_EXE}"
  WriteRegStr HKLM "${UNINSTALL_KEY}" "UninstallString" '"$INSTDIR\Uninstall.exe"'
  WriteRegDWORD HKLM "${UNINSTALL_KEY}" "NoModify" 1
  WriteRegDWORD HKLM "${UNINSTALL_KEY}" "NoRepair" 1
SectionEnd

Section "Uninstall"
  Delete "$DESKTOP\MCLauncher.lnk"
  Delete "$SMPROGRAMS\MCLauncher\MCLauncher.lnk"
  Delete "$SMPROGRAMS\MCLauncher\Удалить MCLauncher.lnk"
  RMDir "$SMPROGRAMS\MCLauncher"
  DeleteRegKey HKCR "mclauncher"
  DeleteRegKey HKLM "${UNINSTALL_KEY}"
  RMDir /r "$INSTDIR"
SectionEnd
