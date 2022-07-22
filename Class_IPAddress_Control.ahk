; ======================================================================================================================
; AHK 1.1.04 +
; ======================================================================================================================
; Function:          Support for IP Address controls - http://msdn.microsoft.com/en-us/library/bb761374%28VS.85%29.aspx
;                    They may be useful in some cases, but they offer very few options for customizing.
; AHK version:       1.1.04.00 (U32)
; Language:          English
; Tested on:         Win XPSP3, Win VistaSP2 (32 Bit)
; Version:           0.0.01.00/2011-09-17/just me
; How to use:        To create a new IP Address control use MyIPAddr := New IPAddress_Control()
;                    passing up to three parameters:
;                       HGUI      - HWND of the GUI                                          (Pointer)
;                       ----------- Optional ---------------------------------------------------------
;                       Options   - Options for positioning and sizing (X, Y, W, H)          (String)
;                                   as used in "Gui, Add" command.
;                                   Defaults: X - automatically positioned by GUI
;                                             Y - automatically positioned by GUI
;                                             W - automatically calculated for the current GUI font
;                                             H - automatically calculated for the current GUI font
;                       IPAddress - IP address as 32-bit integer or string (e.g. 127.0.0.1)  (Integer/String)
;                    On success   - New returns an object with six public keys:
;                       HWND      - HWND of the control                                      (Pointer)
;                       X         - X-position                                               (Integer)
;                       Y         - Y-position                                               (Integer)
;                       W         - Width of the control                                     (Integer)
;                       H         - Height of the control                                    (Integer)
;                       ID        - Id of the control (>= 0x4000)                            (Integer)
;                    On failure   - New returns False, ErrorLevel contains additional informations.
;
;                    To destroy the control afterwards simply assign an empty string or zero (e.g. MyIPAddr := "").
;
;                    This class provides he following public methods described below:
;                       ClearAddr()    - Clears the contents of the IP address control.
;                       GetAddr()      - Gets the address values from all four fields in the IP address control.
;                       SetAddr()      - Sets the address values for all four fields in the IP address control.
;                       IsBlank()      - Determines if all fields in the IP address control are blank.
;                       SetFocus()     - Sets the keyboard focus to the specified field in the IP address control.
;                       SetRange()     - Sets the valid range for the specified field in the IP address control.
;                       Disable()      - Disables the control.
;                       Enable()       - Enables the control.
;                       Addr2Str()     - Converts an IPAddress DWORD into a string.
;                       Str2Addr()     - Converts an IPAddress string into a DWORD.
;
; Remarks:           The control devides the address into four fields which are treated individually.
;                    The field numbers are zero-based and proceed from left to right; these are used with the
;                    methods SetFocus and SetRange. The default range for each field is 0 to 255, but you can set
;                    the range to any values between those limits with the SetRange method.
;
;                    As per MSDN the control will send the EN_SETFOCUS, EN_KILLFOCUS and EN_CHANGE notifications
;                    through WM_COMMAND. It will also send the IPN_FIELDCHANGED (-860) notification through
;                    WM_NOTIFY whenever the user changes a field in the control or moves from one field to another.
;                    I didn't implement built-in notification handling in this version, but it can be added.
;
;                    Names of "private" properties/methods/functions are prefixed with underscores, they must not be
;                    set/called by the script!
; ======================================================================================================================
; This software is provided 'as-is', without any express or implied warranty.
; In no event will the authors be held liable for any damages arising from the use of this software.
; ======================================================================================================================
Class IPAddress_Control {
   ; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
   ; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
   ; PRIVATE Properties and Methods ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
   ; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
   ; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
   ; Messages and notifications ----------------------------------------------------------------------------------------
   ; WM_USER := 0x400
   ; IPN_FIRST := -860
   Static IPM_CLEARADDRESS := (0x400 + 100) ; no parameters
   Static IPM_GETADDRESS   := (0x400 + 102) ; lresult = # of non black fields, lparam = LPDWORD for TCP/IP address
   Static IPM_ISBLANK      := (0x400 + 105) ; no parameters
   Static IPM_SETADDRESS   := (0x400 + 101) ; lparam = TCP/IP address
   Static IPM_SETFOCUS     := (0x400 + 104) ; wparam = field
   Static IPM_SETRANGE     := (0x400 + 103) ; wparam = field, lparam = range
   Static IPN_FIELDCHANGED := -860          ; IPN_FIRST - 0
   ; ===================================================================================================================
   ; CONSTRUCTOR     __New()
   ; ===================================================================================================================
   __New(HGUI, Options = "", IPAddress = "") {
      Global Notification
      Static DefaultFunc := "_IPAddress_Notifications"
      Static INIT := False
      Static HDEFFONT := 0
      Static DEFAULT_GUI_FONT := 17
      Static ICC_INTERNET_CLASSES := 0x00000800
      Static IDC_IPADDRESS := 0x4400
      Static WC_IPADDRESS  := "SysIPAddress32"
      Static WM_SETFONT    := 0x0030
      Static WM_GETFONT    := 0x0031
      Static WS_OVERLAPPED := 0x00000000
      Static WS_TABSTOP    := 0x00010000
      Static WS_VISIBLE    := 0x10000000
      Static WS_CHILD      := 0x40000000
      If !(INIT) {
         VarSetCapacity(ICCX, 8, 0)
         NumPut(8, ICCX, 0, "UInt")
         NumPut(ICC_INTERNET_CLASSES, ICCX, 4, "UInt")
         If !DllCall("Comctl32.dll\InitCommonControlsEx", "Ptr", &ICCX)
            Return False
         HDEFFONT := DllCall("Gdi32.dll\GetStockObject", "Int", DEFAULT_GUI_FONT)
         INIT := True
      }
      If !DllCall("User32.dll\IsWindow", "UPtr", HGUI) {
         ErrorLevel := "Invalid parameter HGUI: " . HGUI
         Return False
      }
      WS_STYLES := WS_VISIBLE | WS_CHILD | WS_TABSTOP
      Opts := {X: "", Y: "", W: "", H: ""}
      Options := Trim(RegExReplace(Options, "\s+", " "))
      Loop, Parse, Options, %A_Space%
      {
         O := SubStr(A_LoopField, 1, 1)
         If InStr("XYWH", O)
            Opts[O] := A_LoopField
      }
      Options := Opts.X . " " . Opts.Y . " " . Opts.W . " " . Opts.H
      Gui, %HGUI%:Add, Edit, %Options% +Disabled hwndHDUMMY, "000.0000.0000.0000"
      GuiControlGet, CP, Pos, %HDUMMY%
      GuiControl, , %HDUMMY%
      HFONT := DllCall("SendMessage", "Ptr", HDUMMY, "Int", WM_GETFONT, "Ptr", 0, "Ptr", 0, "UPtr")
      If !(HFONT)
         HFONT := HDEFFONT
      HIP := DllCall("CreateWindowEx", "UInt", 0, "Str", WC_IPADDRESS, "Str", "", "UInt", WS_STYLES
                   , "Int", CPX, "Int", CPY, "Int", CPW, "Int", CPH
                   , "Ptr", HGUI, "Ptr", IDC_IPADDRESS, "Ptr", 0, "Ptr", 0, "Ptr")
      If ((ErrorLevel) || !(HIP)) {
         ErrorMsg := "Couldn't create IPAddress control!`nErrorLevel: " . ErrorLevel . " - HWND: " . HIP
         ErrorLevel := ErrorMsg
         Return False
      }
      DllCall("SendMessage", "Ptr", HIP, "Int", WM_SETFONT, "Ptr", HFONT, "Ptr", 1)
      ; Get the HWNDs of the Edit fields
      Edits := []
      If (HEDIT := DllCall("User32.dll\GetWindow", "Ptr", HIP, "UInt", 5, "Ptr")) {
         Edits.Insert(HEDIT)
         While (HEDIT := DllCall("User32.dll\GetWindow", "Ptr", HEDIT, "UInt", 2, "Ptr"))
            Edits.Insert(HEDIT)
      }
      This.HWND := HIP
      This.X := X
      This.Y := Y
      This.W := W
      This.H := H
      This.ID := IDC_IPADDRESS
      IDC_IPADDRESS += 1
      This._Edits := Edits
      If (IPAddress <> "") {
         IsStr := True
         If IPAddress Is Integer
            IsStr := False
         This.SetAddr(IPAddress, IsStr)
      }
   }
   ; ===================================================================================================================
   ; DESTRUCTOR      __Delete()
   ; ===================================================================================================================
   __Delete() {
      Global Notification
      If (This.HWND) {
         DllCall("DestroyWindow", "Ptr", This.HWND)
         ; Notification.Unregister(This.HWND, NM_CLICK)
         ; Notification.Unregister(This.HWND, NM_RETURN)
      }
   }
   ; ===================================================================================================================
   ; PRIVATE METHOD   _MakeIPRange  - Packs two byte-values into a single LPARAM suitable for use with the
   ;                                  IPM_SETRANGE message.
   ; ===================================================================================================================
   _MakeIPRange(LowLimit, HighLimit) {
      If ((LowLimit & 0xFF) = LowLimit)
      && ((HighLimit & 0xFF) = HighLimit)
      && (LowLimit <= HighLimit)
         Return (LowLimit | (HighLimit << 8))
      Return ""
   }
   ; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
   ; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
   ; PUBLIC Interface ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
   ; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
   ; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
   ; ===================================================================================================================
   ; PUBLIC METHOD   ClearAddr      - Clears the contents of the IP address control.
   ; Parameters:     None
   ; Return value:   The return value is not used.
   ; ===================================================================================================================
   ClearAddr() {
      If (!This.HWND)
         Return
      DllCall("SendMessage", "Ptr", This.HWND, "Int", This.IPM_CLEARADDRESS, "Ptr", 0, "Ptr", 0)
      Return
   }
   ; ===================================================================================================================
   ; PUBLIC METHOD   GetAddr        - Gets the address values for all four fields in the IP address control.
   ; Parameters:     Optional:
   ;                 AsStr          - True returns IPAddr as string, whereas False as number
   ; Return Value:   On sucess      - IPAddress
   ;                 On failure     - False
   ; ===================================================================================================================
   GetAddr(AsStr = True) {
      If (!This.HWND)
         Return False
      DWAddr := 0
      Fields :=  DllCall("SendMessage", "Ptr", This.HWND, "Int", This.IPM_GETADDRESS, "Ptr", 0, "UIntP", DWAddr)
      If (Fields <> 4)
         Return False
      If !(AsStr)
         Return DWAddr
      Return This.Addr2STr(DWAddr)
   }
   ; ===================================================================================================================
   ; PUBLIC METHOD   SetAddr        - Sets the address values for all four fields in the IP address control.
   ; Parameters:     IPAddr         - IP address as 32-bit integer or string
   ; Return value:   On success     - True
   ;                 On failure     - False
   ; ===================================================================================================================
   SetAddr(IPAddr) {
      If (!This.HWND)
         Return False
      If IPAddr Is Not Integer
         IPAddr := This.Str2Addr(IPAddr)
      Else
         IPAddr := IPAddr & 0xFFFFFFFF
      Return DllCall("SendMessage", "Ptr", This.HWND, "Int", This.IPM_SETADDRESS, "Ptr", 0, "UPtr", IPAddr)
   }
   ; ===================================================================================================================
   ; PUBLIC METHOD   IsBlank        - Determines if all fields in the IP address control are blank.
   ; Parameters:     None
   ; Return value:   True if all fields are empty, otherwise False
   ; ===================================================================================================================
   IsBlank() {
      If (!This.HWND)
         Return False
      Return DllCall("SendMessage", "Ptr", This.HWND, "Int", This.IPM_ISBLANK, "Ptr", 0, "Ptr", 0)
   }
   ; ===================================================================================================================
   ; PUBLIC METHOD   SetFocus       - Sets the keyboard focus to the specified field in the IP address control.
   ; Parameter:      Index          - One based field index proceeding from left to right.
   ;                                  If this value is greater than the number of fields, focus is set to the first
   ;                                  blank field. If all fields are nonblank, focus is set to the first field.
   ; Return value:   The return value is not used.
   ; ===================================================================================================================
   SetFocus(Index) {
      If (!This.HWND)
         Return
      If Index Not Between 1 And 4
         Index := 6
      Index--
      DllCall("SendMessage", "Ptr", This.HWND, "Int", This.IPM_SETFOCUS, "Ptr", Index, "Ptr", 0)
      Return
   }
   ; ===================================================================================================================
   ; PUBLIC METHOD   SetRange       - Sets the valid range for the specified field in the IP address control.
   ; Parameters:     Index          - One based field index proceeding from left to right.
   ;                                  Range: 1 - 4
   ;                 LowLimit       - Low limit as integer
   ;                                  Range: 0 - 255
   ;                 HighLimit      - High limit as integer
   ;                                  Range: LowLimit - 255
   ; Return value:   On success     - True
   ;                 On failure     - False
   ; ===================================================================================================================
   SetRange(Index, LowLimit, HighLimit) {
      If (!This.HWND)
         Return False
      If Index Not Between 1 And 4
         Return False
      Index--
      IPRange := This._MakeIPRange(LowLimit, HighLimit)
      If IPRange Is Integer
         Return DllCall("SendMessage", "Ptr", This.HWND, "Int", This.IPM_SETRANGE, "Ptr", Index, "Ptr", IPRange)
      Return False
   }
   ; ===================================================================================================================
   ; PUBLIC METHOD   Addr2Str       - Converts an IPAddress DWORD into a string.
   ; Parameters:     IPAddr         - IP address as string
   ; Return value:   On success     - True
   ;                 On failure     - False
   ; ===================================================================================================================
   Addr2Str(IPAddr) {
      If IPAddr Is Not Integer
         Return False
      IPAddr := IPAddr & 0xFFFFFFFF
      Result := ""
      Loop, 4 {
         SL := (4 - A_Index) * 8
         Result .= (((IPAddr & (0xFF << SL)) >> SL) + 0) . "."
      }
      Return SubStr(Result, 1, -1)
   }
   ; ===================================================================================================================
   ; PUBLIC METHOD   Str2Addr       - Converts an IPAddress string into a DWORD.
   ; Parameters:     IPAddr         - IP address as 32-bit integer
   ; Return value:   On success     - True
   ;                 On failure     - False
   ; ===================================================================================================================
   Str2Addr(IPString) {
      If !RegExMatch(IPString, "^(?:\d{1,3}\.){3}\d{1,3}$")
         Return False
      Result := 0
      Loop, Parse, IPString, .
      {
         If ((A_LoopField & 0xFF) <> A_LoopField)
            Return False
         Result += A_LoopField << ((4 - A_Index) * 8)
      }
      Return Result
   }
   ; ===================================================================================================================
   ; PUBLIC METHOD   Disable        - Disables the control.
   ; Parameters:     None
   ; Return value:   On success     - True
   ;                 On failure     - False
   ; ===================================================================================================================
   Disable() {
      Static GWL_STYLE := -16
      Static WS_DISABLED := 0x08000000
      If !(This.HWND)
         Return False
      Suf := (A_PtrSize = 8 ? "Ptr" : "")
      For Each, HWND In This._Edits {
         Styles := DllCall("User32.dll\GetWindowLong" . Suf, "Ptr", HWND, "Int", GWL_STYLE, "Int")
         If (ErrorLevel)
            Return False
         If (Styles & WS_DISABLED)
            Continue
         Styles |= WS_DISABLED
         DllCall("User32.dll\SetWindowLong" . Suf, "Ptr", HWND, "Int", GWL_STYLE, "Ptr", Styles)
      }
      Return True
   }
   ; ===================================================================================================================
   ; PUBLIC METHOD   Enable         - Enables the control.
   ; Parameters:     None
   ; Return value:   On success     - True
   ;                 On failure     - False
   ; ===================================================================================================================
   Enable() {
      Static GWL_STYLE := -16
      Static WS_DISABLED := 0x08000000
      If !(This.HWND)
         Return False
      Suf := (A_PtrSize = 8 ? "Ptr" : "")
      For Each, HWND In This._Edits {
         Styles := DllCall("User32.dll\GetWindowLong" . Suf, "Ptr", HWND, "Int", GWL_STYLE, "Int")
         If (ErrorLevel)
            Return False
         If !(Styles & WS_DISABLED)
            Continue
         Styles ^= WS_DISABLED
         DllCall("User32.dll\SetWindowLong" . Suf, "Ptr", HWND, "Int", GWL_STYLE, "Ptr", Styles)
      }
      Return True
   }
}
; ======================================================================================================================

