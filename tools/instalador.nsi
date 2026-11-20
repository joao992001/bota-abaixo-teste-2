; Instalador do Bota-Abaixo para Windows (NSIS). Gera out/Instalar-Bota-Abaixo.exe.
; Instala para o usuário atual (não pede administrador), cria atalhos e desinstalador.
Unicode true
!include "MUI2.nsh"

Name "Bota-Abaixo"
OutFile "../out/Instalar-Bota-Abaixo.exe"
InstallDir "$LOCALAPPDATA\Programs\Bota-Abaixo"
InstallDirRegKey HKCU "Software\Bota-Abaixo" "Pasta"
RequestExecutionLevel user
SetCompressor /SOLID lzma
BrandingText "Bota-Abaixo"

!define MUI_ICON "icone.ico"
!define MUI_UNICON "icone.ico"
!define MUI_ABORTWARNING
!define MUI_FINISHPAGE_RUN "$INSTDIR\Bota-Abaixo.exe"
!define MUI_FINISHPAGE_RUN_TEXT "Jogar agora"

!define MUI_COMPONENTSPAGE_NODESC
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_COMPONENTS
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "PortugueseBR"

Section "Bota-Abaixo (o jogo)" SecJogo
	SectionIn RO
	SetShellVarContext current
	SetOutPath "$INSTDIR"
	File "../out/build/windows/Bota-Abaixo.exe"
	File "/oname=Bota-Abaixo.ico" "icone.ico"
	WriteUninstaller "$INSTDIR\Desinstalar.exe"
	WriteRegStr HKCU "Software\Bota-Abaixo" "Pasta" "$INSTDIR"
	WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Bota-Abaixo" "DisplayName" "Bota-Abaixo"
	WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Bota-Abaixo" "DisplayIcon" "$INSTDIR\Bota-Abaixo.ico"
	WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Bota-Abaixo" "UninstallString" '"$INSTDIR\Desinstalar.exe"'
	WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Bota-Abaixo" "Publisher" "Bota-Abaixo"
	WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Bota-Abaixo" "DisplayVersion" "0.1"
	WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Bota-Abaixo" "NoModify" 1
	WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Bota-Abaixo" "NoRepair" 1
SectionEnd

Section "Criar atalho na área de trabalho" SecDesktop
	SetShellVarContext current
	CreateShortcut "$DESKTOP\Bota-Abaixo.lnk" "$INSTDIR\Bota-Abaixo.exe" "" "$INSTDIR\Bota-Abaixo.ico"
SectionEnd

Section "Criar atalho no menu Iniciar" SecMenu
	SetShellVarContext current
	CreateDirectory "$SMPROGRAMS\Bota-Abaixo"
	CreateShortcut "$SMPROGRAMS\Bota-Abaixo\Bota-Abaixo.lnk" "$INSTDIR\Bota-Abaixo.exe" "" "$INSTDIR\Bota-Abaixo.ico"
	CreateShortcut "$SMPROGRAMS\Bota-Abaixo\Desinstalar Bota-Abaixo.lnk" "$INSTDIR\Desinstalar.exe"
SectionEnd

Section "Uninstall"
	SetShellVarContext current
	Delete "$INSTDIR\Bota-Abaixo.exe"
	Delete "$INSTDIR\Bota-Abaixo.ico"
	Delete "$INSTDIR\Desinstalar.exe"
	RMDir "$INSTDIR"
	Delete "$SMPROGRAMS\Bota-Abaixo\Bota-Abaixo.lnk"
	Delete "$SMPROGRAMS\Bota-Abaixo\Desinstalar Bota-Abaixo.lnk"
	RMDir "$SMPROGRAMS\Bota-Abaixo"
	Delete "$DESKTOP\Bota-Abaixo.lnk"
	DeleteRegKey HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Bota-Abaixo"
	DeleteRegKey HKCU "Software\Bota-Abaixo"
SectionEnd
