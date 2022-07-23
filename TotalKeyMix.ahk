;=================== TotalKeyMix 1.5.0 ===================

;****************** Control the volume on the TotalMix application of the RME soundcards via computer keyboard ****************
;****************** coded by Kip Chatterson (framework and main functionality) ************************************************
;****************** coded by Stephan Römer (GUI, assignable hotkeys, INI reading & saving) ************************************
;****************** coded by Rajat (Volume On-Screen-Display) *****************************************************************
;****************** coded by Petre Ikonomov (changes since v.1.0.2) ***********************************************************
;****************** coded by Tim Jaacks (changes since v.1.3.0) ***************************************************************

;****************** Maintained at https://github.com/carlfriedrich/TotalKeyMix ************************************************

;*************** carlfriedrich's 1.5.0 Modified to replace all MIDI comms with OSC protocol (temporaly ? named  TotalKeyMixOSC)
;**************** with help from:
;****************		OSC2AHK.DLL by Ludwig / nyquist:
; ***************					https://www.autohotkey.com/boards/viewtopic.php?t=89647
;**************** 					https://files.eleton-audio.de/gitea/Ludwig/OSC2AHK
;****************		Class_IPAddress_Control.ahk from "just me"
;****************					https://www.autohotkey.com/board/topic/71490-class-ipaddress-control-support-for-ip-address-controls/
;****************
;****************




/*
The following file (general functions.ahk) must be included in the directory of the script - if you compile to exe, then you won't need it since it is built into it.
the file was taken from the midiout thread on ahk forum: http://www.autohotkey.com/forum/topic18711.html
*/

#SingleInstance Off
#MaxHotkeysPerInterval 400		; higher interval needed when using a continous controller like the Griffin PowerMate
#NoEnv
OnExit, ShutApp

;=================== Get config file from command line argument ===================
if %1% {
	ConfigFile = %1%
} else {
	ConfigFile = config.ini
}

;=================== Define Variables ===================

  IniRead, OSC_SendingPort, %ConfigFile%, OSC, Port					; TotalMix OSC port
  IniRead, OSC_TotalMixIp, %ConfigFile%, OSC, IP					; TotalMix IP address
  IniRead, OSC_addr, %ConfigFile%, OSC, Address						; OSC address
  IniRead, CCIntVal, %ConfigFile%, Volume, LastValue				; This restores the last volume value from the config file
  IniRead, VolumeStepVal, %ConfigFile%, Volume, VolumeStep			; This value from the config file adjusts the value change when pressing the Volume buttons
  IniRead, VolumeMaxVal, %ConfigFile%, Volume, MaxValue			; Maximum volume
  IniRead, HideTrayIconVal, %ConfigFile%, Settings, HideTrayIcon			; set in the config file (1 hides Tray Icon, 0 shows)
  IniRead, vol_DisplayTime, %ConfigFile%, OSD, DisplayTime				; How long to display the volume level bar graph
  IniRead, vol_CBM, %ConfigFile%, OSD, Color								; Volume Bar color (see the help file to use more precise shades)
  IniRead, vol_CW, %ConfigFile%, OSD, BackgroundColor						; Volume Bar background color
  IniRead, vol_PosX, %ConfigFile%, OSD, PosX								; Volume Bar's horizontal screen position.  Use -1 to center the bar in that dimension:
  IniRead, vol_PosY, %ConfigFile%, OSD, PosY								; Volume Bar's vertical screen position.  Use -1 to center the bar in that dimension:
  IniRead, vol_Width, %ConfigFile%, OSD, Width							; width of Volume Bar
  IniRead, vol_Thick, %ConfigFile%, OSD, Height							; thickness of Volume Bar
  MuteState:= 0					; default mute state = off
  CCIntValMute:= 0				; stored volume before mute
  ToggleSetup:= 0				; toggle state of the setup GUI

vol_BarOptions = 1:B ZH%vol_Thick% ZX0 ZY0 W%vol_Width% CB%vol_CBM% CW%vol_CW%

if vol_PosX >= 0		; If the X position has been specified, add it to the options.  Otherwise, omit it to center the bar horizontally.
{
	vol_BarOptions = %vol_BarOptions% X%vol_PosX%
}

if vol_PosY >= 0		; If the Y position has been specified, add it to the options.  Otherwise, omit it to center the bar vertically.
{
	vol_BarOptions = %vol_BarOptions% Y%vol_PosY%
}

SetBatchLines, 10ms


;=================== OSC stuff ===================

; Load DLL
hModule := DllCall("LoadLibrary", "Str", "OSC2AHK.dll", "Ptr")


;=================== Define Hotkey Triggers ===================

IniRead, EnterVolumeUpHotkey, %ConfigFile%, Hotkeys, VolumeUpHotkey			; read setting from %ConfigFile% and write it into variable "EnterVolumeUpHotkey"
IniRead, EnterVolumeDownHotkey, %ConfigFile%, Hotkeys, VolumeDownHotkey		; read setting from %ConfigFile% and write it into variable "EnterVolumeDownHotkey"
IniRead, EnterVolumeMuteHotkey, %ConfigFile%, Hotkeys, VolumeMuteHotkey		; read setting from %ConfigFile% and write it into variable "EnterVolumeMuteHotkey"														; read hotkeys from %ConfigFile%		
Hotkey, %EnterVolumeUpHotkey%, VolumeUp 									; assign variable (stored hotkey) to function "VolumeUp" 
Hotkey, %EnterVolumeDownHotkey%, VolumeDown									; assign variable (stored hotkey) to function "VolumeDown"
Hotkey, %EnterVolumeMuteHotkey%, VolumeMute									; assign variable (stored hotkey) to function "VolumeMute"


;=================== Setup GUI ===================
Menu, Tray, NoStandard														; don't show the default ahk menu on the tray
If HideTrayIconVal=0
{
	Menu, Tray, Icon, icon.ico												; assign custom icon
}
If HideTrayIconVal=1
{
	Menu, Tray, NoIcon
}
Menu, Tray, Add, Setup, GuiShow												; add menu entry "Setup"
Menu, Tray, Add																; add seperator
Menu, Tray, Add, Exit, QuitScript											; add menu entry "Exit"
Menu, Tray, Default, Setup													; default action on left click = "Setup"
Menu, Tray, Click, 1														; left single click enabled
return

QuitScript:
 ExitApp
return

GuiShow:
if ToggleSetup = 0																				; if setup screen is not visible, create it
{
ToggleSetup = 1																					; set toggle variable to "setup is shown"
   
Gui, Add, Text, x152 y20 w130 h20 +Center, TotalKeyMix Setup 									; text

;******* volume up hotkey assignment *******
Gui, Add, Text, x30 y80 w200 h20 , Volume Up Hotkey												; text
Gui, Add, Hotkey, x180 y80 w210 h20 vEnterVolumeUpHotkey, %EnterVolumeUpHotkey%					; show assigned hotkey in input field and write new input to EnterVolumeUpHotkey on Submit

;******* volume down hotkey assignment *******
Gui, Add, Text, x30 y120 w200 h20 , Volume Down Hotkey											; text
Gui, Add, Hotkey, x180 y120 w210 h20 vEnterVolumeDownHotkey, %EnterVolumeDownHotkey%			; show assigned hotkey in input field and write new input to EnterVolumeDownHotkey on Submit

;******* volume mute hotkey assignment *******
Gui, Add, Text, x30 y160 w200 h20 , Volume Mute Hotkey											; text
Gui, Add, Hotkey, x180 y160 w210 h20 vEnterVolumeMuteHotkey, %EnterVolumeMuteHotkey%			; show assigned hotkey in input field and write new input to EnterVolumeMuteHotkey on Submit

;******* TotalMix IP assignment *******
Gui, Add, Text, x30 y200 w200 h20 , Totalmix FX OSC service IP									; text
Gui, Add, Edit, x180 y200 w210 h20 r1 vOSC_TotalMixIp, %OSC_TotalMixIp%							; show IP address in input field and write new input to OSC_TotalMixIp on Submit

;******* TotalMix Port assignment *******
Gui, Add, Text, x30 y240 w200 h20 , Totalmix "OSC Port incoming"								; text
Gui, Add, Edit, x180 y240 w210 h20 r1 Number vOSC_SendingPort, %OSC_SendingPort%				; show port in input field and write new input to OSC_SendingPort on Submit

Gui, Add, Button, x252 y310 w110 h30 , OK 														; create ok button
Gui, Add, Button, x62 y310 w100 h30 , Cancel 													; create cancel button
Gui, Show, x304 y135 h396 w427, TotalKeyMix Setup 												; show GUI
return

}
Else
{
   ToggleSetup = 0																				; set toggle variable to "setup hidden"
   Gui, destroy
}
return


;******* ok button function *******

ButtonOK:
Gui, Submit																						; submit changed values in GUI
IniWrite, %EnterVolumeUpHotkey%, %ConfigFile%, Hotkeys, VolumeUpHotkey							; write hotkey settings to %ConfigFile%
IniWrite, %EnterVolumeDownHotkey%, %ConfigFile%, Hotkeys, VolumeDownHotkey						; write hotkey settings to %ConfigFile%
IniWrite, %EnterVolumeMuteHotkey%, %ConfigFile%, Hotkeys, VolumeMuteHotkey						; write hotkey settings to %ConfigFile%
Hotkey, %EnterVolumeUpHotkey%, VolumeUp															; re-assign hotkeys with saved value
Hotkey, %EnterVolumeDownHotkey%, VolumeDown														; re-assign hotkeys with saved value
Hotkey, %EnterVolumeMuteHotkey%, VolumeMute														; re-assign hotkeys with saved value
IniWrite, %OSC_TotalMixIp%, %ConfigFile%, OSC, IP												; write ip value to %ConfigFile%
IniWrite, %OSC_SendingPort%, %ConfigFile%, OSC, Port											; write port value to %ConfigFile%

ToggleSetup = 0																					; set toggle variable to "setup hidden"
Gui, destroy
return

;******* cancel button function *******

ButtonCancel:
ToggleSetup = 0																					; set toggle variable to "setup hidden"
Gui, destroy
return

GuiClose:
ToggleSetup = 0	
Gui, destroy
return

ShutApp:
IniWrite, %CCIntVal%, %ConfigFile%, Volume, LastValue
DllCall("FreeLibrary", "Ptr", hModule)  ; To conserve memory, the DLL may be unloaded after using it   (useful?)
ExitApp
return

;=================== Define Keys For MIDI Output CC Value ===================

;******* volume up command ********  

VolumeUp:
If MuteState = 1
	{
	MuteState:= 0
	CCIntVal:= CCIntValMute
	}
	CCIntVal := CCIntVal < VolumeMaxVal ? CCIntVal+VolumeStepVal : VolumeMaxVal
	DllCall("OSC2AHK.dll\sendOscMessageFloat", AStr, OSC_TotalMixIp, UInt, OSC_SendingPort, AStr, OSC_addr, Float, CCIntVal)
	Gosub, vol_ShowBars
return

;********* volume down command *************

VolumeDown:
If MuteState = 1
	{
	MuteState:= 0
	CCIntVal:= CCIntValMute
	}
	CCIntVal := CCIntVal > 0 ? CCIntVal-VolumeStepVal : 0
	DllCall("OSC2AHK.dll\sendOscMessageFloat", AStr, OSC_TotalMixIp, UInt, OSC_SendingPort, AStr, OSC_addr, Float, CCIntVal)
	Gosub, vol_ShowBars 
return

;********* volume mute command *************

VolumeMute:
If MuteState = 0
	{
	MuteState:= 1
	CCIntValMute:= CCIntVal
	CCIntVal:= 0
	DllCall("OSC2AHK.dll\sendOscMessageFloat", AStr, OSC_TotalMixIp, UInt, OSC_SendingPort, AStr, OSC_addr, Float, CCIntVal)
	Gosub, vol_ShowBars
	return
	}

If MuteState = 1
	{
	MuteState:= 0
	CCIntVal:= CCIntValMute
	DllCall("OSC2AHK.dll\sendOscMessageFloat", AStr, OSC_TotalMixIp, UInt, OSC_SendingPort, AStr, OSC_addr, Float, CCIntVal)
	Gosub, vol_ShowBars
	return
	}

return

vol_ShowBars:
CCIntValOSD := (CCIntVal/VolumeMaxVal)*100
IfWinNotExist, %ConfigFile%		; To prevent the "flashing" effect, only create the bar window if it doesn't already exist.
{
	Progress, %vol_BarOptions%, , , %ConfigFile%
}
Progress, 1:%CCIntValOSD%		; Get volume %.
IfWinNotActive, %ConfigFile%
{
	WinActivate, %ConfigFile%
}
SetTimer, vol_BarOff, %vol_DisplayTime%
return

vol_BarOff:
SetTimer, vol_BarOff, off
Progress, 1:Off
return

/*  this seems it's never called
midiOutClose(h_midiout) 										; stop midi output
OpenCloseMidiAPI()
*/


/*
DllCall("FreeLibrary", "Ptr", hModule)  ; To conserve memory, the DLL may be unloaded after using it
result := DllCall("OSC2AHK\close", UInt, 1)  ;1= remove all listeners also
*/
