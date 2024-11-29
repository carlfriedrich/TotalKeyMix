;=================== TotalKeyMix 1.6.3 ===================

;****************** Control the volume on the TotalMix application of the RME soundcards via computer keyboard ****************
;****************** coded by Kip Chatterson (framework and main functionality) ************************************************
;****************** coded by Stephan Römer (GUI, assignable hotkeys, INI reading & saving) ************************************
;****************** coded by Rajat (Volume On-Screen-Display) *****************************************************************
;****************** coded by Petre Ikonomov (changes since v.1.0.2) ***********************************************************
;****************** coded by Tim Jaacks (changes since v.1.3.0) ***************************************************************

;****************** Maintained at https://github.com/carlfriedrich/TotalKeyMix ************************************************

; Socket.ahk Taken from here: https://github.com/G33kDude/Socket.ahk
#Include Socket.ahk

#SingleInstance Off
; higher interval needed when using a continuous controller like the Griffin PowerMate
#MaxHotkeysPerInterval 400
#NoEnv
OnExit, CloseApp

;=================== Get config file from command line argument ===================
if %1% {
    configFilePath = %1%
} else {
    configFilePath = config.ini
}

;=================== Define Variables ===================

IniRead, oscPort, %configFilePath%, OSC, Port
IniRead, oscIP, %configFilePath%, OSC, IP
IniRead, oscAddress, %configFilePath%, OSC, Address
IniRead, volumeLevel, %configFilePath%, Volume, LastValue
IniRead, volumeStepSize, %configFilePath%, Volume, VolumeStep
IniRead, volumeMax, %configFilePath%, Volume, MaxValue
IniRead, hideTrayIcon, %configFilePath%, Settings, HideTrayIcon
IniRead, osdDisplayTime, %configFilePath%, OSD, DisplayTime
IniRead, osdForegroundColor, %configFilePath%, OSD, Color
IniRead, osdBackgroundColor, %configFilePath%, OSD, BackgroundColor
IniRead, osdPosX, %configFilePath%, OSD, PosX
IniRead, osdPosY, %configFilePath%, OSD, PosY
IniRead, osdWidth, %configFilePath%, OSD, Width
IniRead, osdHeight, %configFilePath%, OSD, Height

isMuted := 0
previousVolumeLevel := 0
setupGUIVisible := 0

osdBarOptions = 1:B ZH%osdHeight% ZX0 ZY0 W%osdWidth% CB%osdForegroundColor% CW%osdBackgroundColor%

; If X or Y position has been specified, add it to the options.
; Otherwise, omit it to center the bar in the according dimension.
if osdPosX >= 0
{
    osdBarOptions := %osdBarOptions% X%osdPosX%
}
if osdPosY >= 0
{
    osdBarOptions := %osdBarOptions% Y%osdPosY%
}

SetBatchLines, 10ms


;=================== OSC stuff ===================

Align32Bit(x)
{
    return Ceil(x / 4) * 4
}

ZeroMemory(ByRef destination, bytes)
{
    DllCall("ntdll.dll\RtlZeroMemory", "Ptr", destination, "UInt", bytes)
}

FloatByteSwap(f)
{
    ; first interpret the flat's bytes as int in order to be able to apply bitwise operators
    VarSetCapacity(v, 4, 0)
    numput(f, v, 0, "float")
    i := numget(v, 0, "uint")

    ; then swap the bytes
    swapped := (0xFF000000 & i) >> 24 | (0xFF0000 & i) >> 8 | (0xFF00 & i) << 8 | (0xFF & i) << 24

    ; and interpret the bytes as float again
    VarSetCapacity(v, 4, 0)
    numput(swapped, v, 0, "uint")
    return numget(v, 0, "float")
}

OSCSendFloatMessage(socket, address, floatValue)
{
    ; OSC Specification:
    ; https://ccrma.stanford.edu/groups/osc/spec-1_0.html

    addressLength := Align32Bit(StrLen(address) + 1)

    typeTag := ",f"
    typeTagLength := Align32Bit(StrLen(typeTag) + 1)

    floatValueLength := 4

    bufferSize := addressLength + typeTagLength + floatValueLength

    VarSetCapacity(buffer, bufferSize)
    ZeroMemory(&buffer, bufferSize)
    StrPut(address, &buffer, "UTF-8")
    StrPut(typeTag, &buffer + addressLength, "UTF-8")
    NumPut(FloatByteSwap(floatValue), &buffer + addressLength + typeTagLength , "float")

    socket.Send(&buffer, bufferSize)
}

socket := new SocketUDP()
socket.Connect([oscIP, oscPort])

;=================== Define Hotkey Triggers ===================

IniRead, volumeUpHotkey, %configFilePath%, Hotkeys, VolumeUpHotkey
IniRead, volumeDownHotkey, %configFilePath%, Hotkeys, VolumeDownHotkey
IniRead, volumeMuteHotkey, %configFilePath%, Hotkeys, VolumeMuteHotkey
Hotkey, %volumeUpHotkey%, VolumeUp 
Hotkey, %volumeDownHotkey%, VolumeDown
Hotkey, %volumeMuteHotkey%, VolumeMute


;=================== Setup GUI ===================
; don't show the default ahk menu on the tray
Menu, Tray, NoStandard
if (hideTrayIcon=0) and (FileExist("icon.ico"))
{
    Menu, Tray, Icon, icon.ico
}
if hideTrayIcon=1
{
    Menu, Tray, NoIcon
}
Menu, Tray, Add, Setup, ShowSetupGUI
; add seperator
Menu, Tray, Add
Menu, Tray, Add, Exit, QuitScript
; default action on left click = "Setup"
Menu, Tray, Default, Setup
; left single click enabled
Menu, Tray, Click, 1
return

QuitScript:
socket.Disconnect()
ExitApp
return

ShowSetupGUI:
if setupGUIVisible = 0
{
    setupGUIVisible := 1
    
    Gui, Add, Text, x152 y20 w130 h20 +Center, TotalKeyMix Setup

    ;******* volume up hotkey assignment *******
    Gui, Add, Text, x30 y80 w240 h20 , Volume Up Hotkey
    Gui, Add, Hotkey, x220 y80 w170 h20 vVolumeUpHotkey, %volumeUpHotkey%

    ;******* volume down hotkey assignment *******
    Gui, Add, Text, x30 y120 w240 h20 , Volume Down Hotkey
    Gui, Add, Hotkey, x220 y120 w170 h20 vVolumeDownHotkey, %volumeDownHotkey%

    ;******* volume mute hotkey assignment *******
    Gui, Add, Text, x30 y160 w240 h20 , Volume Mute Hotkey
    Gui, Add, Hotkey, x220 y160 w170 h20 vVolumeMuteHotkey, %volumeMuteHotkey%

    ;******* TotalMix IP assignment *******
    Gui, Add, Text, x30 y200 w240 h20 , Totalmix FX OSC IP
    Gui, Add, Edit, x220 y200 w170 h20 r1 vOscIP, %oscIP%

    ;******* TotalMix Port assignment *******
    Gui, Add, Text, x30 y240 w240 h20 , Totalmix FX OSC Port incoming
    Gui, Add, Edit, x220 y240 w170 h20 r1 Number vOscPort, %oscPort%

    ;******* TotalMix Port assignment *******
    Gui, Add, Text, x30 y280 w240 h20 , OSC Address
    Gui, Add, Edit, x220 y280 w170 h20 r1 vOscAddress, %oscAddress%

    Gui, Add, Button, x252 y330 w110 h30 , OK
    Gui, Add, Button, x62 y330 w100 h30 , Cancel
    Gui, Show, x304 y135 h396 w427, TotalKeyMix Setup
    return
}
else
{
   setupGUIVisible := 0
   Gui, destroy
}
return


;******* ok button function *******

ButtonOK:
; submit changed values in GUI
Gui, Submit
; write hotkey settings to config file
IniWrite, %volumeUpHotkey%, %configFilePath%, Hotkeys, VolumeUpHotkey
IniWrite, %volumeDownHotkey%, %configFilePath%, Hotkeys, VolumeDownHotkey
IniWrite, %volumeMuteHotkey%, %configFilePath%, Hotkeys, VolumeMuteHotkey
; re-assign hotkeys with saved value
Hotkey, %volumeUpHotkey%, VolumeUp
Hotkey, %volumeDownHotkey%, VolumeDown
Hotkey, %volumeMuteHotkey%, VolumeMute
; write OSC settings to config file
IniWrite, %oscIP%, %configFilePath%, OSC, IP
IniWrite, %oscPort%, %configFilePath%, OSC, Port
IniWrite, %oscAddress%, %configFilePath%, OSC, Address
; close and re-open socket
socket.Disconnect()
socket.Connect([oscIP, oscPort])
setupGUIVisible := 0
Gui, destroy
return

;******* cancel button function *******

ButtonCancel:
setupGUIVisible := 0
Gui, destroy
return

GuiClose:
setupGUIVisible := 0
Gui, destroy
return

CloseApp:
IniWrite, %volumeLevel%, %configFilePath%, Volume, LastValue
socket.Disconnect()
ExitApp
return

;=================== Define Keys For MIDI Output CC Value ===================

;******* volume up command ********  

VolumeUp:
if isMuted = 1
{
    isMuted := 0
    volumeLevel := previousVolumeLevel
}
volumeLevel := volumeLevel + volumeStepSize < volumeMax ? volumeLevel + volumeStepSize : volumeMax
OSCSendFloatMessage(socket, "/1/busOutput", 1)
OSCSendFloatMessage(socket, oscAddress, volumeLevel)
Gosub, ShowOSDBar
return

;********* volume down command *************

VolumeDown:
if isMuted = 1
{
    isMuted := 0
    volumeLevel := previousVolumeLevel
}
volumeLevel := volumeLevel > 0 ? volumeLevel - volumeStepSize : 0
OSCSendFloatMessage(socket, "/1/busOutput", 1)
OSCSendFloatMessage(socket, oscAddress, volumeLevel)
Gosub, ShowOSDBar 
return

;********* volume mute command *************

VolumeMute:
if isMuted = 0
{
    isMuted := 1
    previousVolumeLevel := volumeLevel
    volumeLevel := 0
    OSCSendFloatMessage(socket, "/1/busOutput", 1)
    OSCSendFloatMessage(socket, oscAddress, volumeLevel)
    Gosub, ShowOSDBar
    return
}

if isMuted = 1
{
    isMuted := 0
    volumeLevel := previousVolumeLevel
    OSCSendFloatMessage(socket, "/1/busOutput", 1)
    OSCSendFloatMessage(socket, oscAddress, volumeLevel)
    Gosub, ShowOSDBar
    return
}

return

ShowOSDBar:
volumePercent := (volumeLevel / volumeMax) * 100
; To prevent the "flashing" effect, only create the bar window if it doesn't already exist
IfWinNotExist, %configFilePath%
{
    Progress, %osdBarOptions%, , , %configFilePath%
}
Progress, 1:%volumePercent%
WinSet, Top, , %configFilePath%
SetTimer, HideOSDBar, %osdDisplayTime%
return

HideOSDBar:
SetTimer, HideOSDBar, off
Progress, 1:Off
return
