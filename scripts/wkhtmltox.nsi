Unicode true
RequestExecutionLevel admin

!ifndef VERSION
  !define VERSION "0.13.0"
!endif
!ifndef SOURCE_DIR
  !define SOURCE_DIR "package\wkhtmltox"
!endif
!ifndef OUT_FILE
  !define OUT_FILE "wkhtmltox-${VERSION}-windows-installer.exe"
!endif

Name "wkhtmltox ${VERSION}"
OutFile "${OUT_FILE}"
InstallDir "$PROGRAMFILES64\wkhtmltopdf"
InstallDirRegKey HKLM "Software\wkhtmltox" "InstallDir"

VIProductVersion "${VERSION}.0"
VIAddVersionKey "ProductName" "wkhtmltox"
VIAddVersionKey "CompanyName" "wkhtmltopdf"
VIAddVersionKey "FileDescription" "wkhtmltox installer"
VIAddVersionKey "LegalCopyright" "Copyright wkhtmltopdf contributors"
VIAddVersionKey "FileVersion" "${VERSION}"
VIAddVersionKey "ProductVersion" "${VERSION}"

Page directory
Page instfiles
UninstPage uninstConfirm
UninstPage instfiles

Section "wkhtmltox" SEC01
  SetOutPath "$INSTDIR"
  File "${SOURCE_DIR}\LICENSE.txt"
  File "${SOURCE_DIR}\README.txt"
  SetOutPath "$INSTDIR\bin"
  File /r "${SOURCE_DIR}\bin\*.*"
  WriteUninstaller "$INSTDIR\uninstall.exe"
  WriteRegStr HKLM "Software\wkhtmltox" "InstallDir" "$INSTDIR"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\wkhtmltox" "DisplayName" "wkhtmltox ${VERSION}"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\wkhtmltox" "DisplayVersion" "${VERSION}"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\wkhtmltox" "Publisher" "wkhtmltopdf"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\wkhtmltox" "InstallLocation" "$INSTDIR"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\wkhtmltox" "UninstallString" '"$INSTDIR\uninstall.exe"'
  WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\wkhtmltox" "NoModify" 1
  WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\wkhtmltox" "NoRepair" 1
SectionEnd

Section "Uninstall"
  DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\wkhtmltox"
  DeleteRegKey HKLM "Software\wkhtmltox"
  RMDir /r "$INSTDIR"
SectionEnd
