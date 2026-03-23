; Custom NSIS installer script for Collaborator
; This file contains custom installer logic for Windows

; P2 Fix: Define a variable to track PATH modification consent
Var AddToPathCheckbox
Var AddToPathState

!macro customInit
  ; Check if app is already installed
  ReadRegStr $0 HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${UNINSTALL_APP_KEY}" "UninstallString"
  ${If} $0 != ""
    MessageBox MB_YESNO "Collaborator is already installed. Do you want to reinstall?" IDYES customInitContinue
    Abort "Installation cancelled by user."
  ${EndIf}

  customInitContinue:
!macroend

; P2 Fix: Add MUI_PAGE_CUSTOMPAGE for PATH modification consent
!include "MUI2.nsh"

!macro customPreInit
  ; Define the PATH consent page
  PageEx pre
    PageCallbacks customPathPre
  PageExEnd
!macroend

Function customPathPre
  ; Create a checkbox for PATH modification consent
  nsDialogs::Create 1018
  ${If} ${NSD_CreateCheckbox} 0 40u 100% 10u "Add Collaborator to system PATH (for CLI access)"
    Pop $AddToPathCheckbox
    ; Default to checked
    ${NSD_Check} $AddToPathCheckbox
  ${EndIf}
  nsDialogs::Show
FunctionEnd

!macro customInstall
  ; Create desktop shortcut
  CreateShortCut "$DESKTOP\Collaborator.lnk" "$INSTDIR\Collaborator.exe" ""

  ; P2 Fix: Add to PATH only if user consented via checkbox
  ${If} $AddToPathCheckbox != 0
    ${NSD_GetState} $AddToPathCheckbox $AddToPathState
    ${If} $AddToPathState = ${BST_CHECKED}
      ; Store current PATH for uninstall cleanup
      ReadRegStr $0 HKLM "SYSTEM\CurrentControlSet\Control\Session Manager\Environment" "PATH"
      WriteRegStr HKLM "Software\${UNINSTALL_APP_KEY}" "BackupPath" "$0"

      ; Add to PATH
      WriteRegExpandStr HKLM "SYSTEM\CurrentControlSet\Control\Session Manager\Environment" "PATH" "$INSTDIR;$PATH"

      ; Broadcast WM_SETTINGCHANGE to notify other applications
      System::Call 'user32::SendMessageA(i, i, t, i) i (0xffff, 0x1a, "Environment", 0)'

      SetShellVarContext all
      RefreshShellIcons
    ${EndIf}
  ${EndIf}
!macroend

!macro customUninstall
  ; Remove desktop shortcut
  Delete "$DESKTOP\Collaborator.lnk"
  Delete "$SMPROGRAMS\Collaborator.lnk"

  ; P2 Fix: PATH cleanup in uninstall macro
  ; Read the backup PATH from registry
  ReadRegStr $0 HKLM "Software\${UNINSTALL_APP_KEY}" "BackupPath"
  ${If} $0 != ""
    ; Remove our installation directory from PATH
    StrCpy $1 "$INSTDIR;"
    StrCpy $2 "$INSTDIR"

    ; Try to remove both with and without semicolon
    Push $0
    Push $1
    Call RemoveFromString
    Pop $0

    ; Update PATH in registry
    WriteRegExpandStr HKLM "SYSTEM\CurrentControlSet\Control\Session Manager\Environment" "PATH" "$0"

    ; Broadcast WM_SETTINGCHANGE to notify other applications
    System::Call 'user32::SendMessageA(i, i, t, i) i (0xffff, 0x1a, "Environment", 0)'

    ; Clean up backup
    DeleteRegValue HKLM "Software\${UNINSTALL_APP_KEY}" "BackupPath"
  ${EndIf}
!macroend

; P2 Fix: Helper function to remove a substring from a string
Function RemoveFromString
  Exch $1 ; substring to remove
  Exch $0 ; original string

  Push $2 ; result
  Push $3 ; temp
  Push $4 ; len0
  Push $5 ; len1
  Push $6 ; pos
  Push $7 ; match

  StrCpy $2 ""
  StrLen $4 $0
  StrLen $5 $1
  StrCpy $6 0

  ; Loop through original string looking for matches
  loop:
    IntCmp $6 $4 done 0 done
    ; Check if substring matches at current position
    StrCpy $3 $0 $5 $6
    StrCmp $3 $1 match_found

    ; No match, copy character
    StrCpy $7 $0 1 $6
    StrCpy $2 "$2$7"
    IntOp $6 $6 + 1
    Goto loop

  match_found:
    ; Skip the substring (don't copy it)
    IntOp $6 $6 + $5
    Goto loop

  done:
  StrCpy $0 $2

  Pop $7
  Pop $6
  Pop $5
  Pop $4
  Pop $3
  Pop $2
  Pop $1

  Exch $0
FunctionEnd
