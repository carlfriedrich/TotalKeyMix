;=================== TotalKeyMix 1.3.0 ===================

;****************** Control the volume on the TotalMix application of the RME soundcards via computer keyboard ****************
;****************** coded by Kip Chatterson (framework and main functionality) ************************************************
;****************** coded by Stephan Römer (GUI, assignable hotkeys, INI reading & saving) ************************************
;****************** coded by Rajat (Volume On-Screen-Display) *****************************************************************
;****************** coded by Petre Ikonomov (changes since v.1.0.2) ***********************************************************
;****************** coded by Tim Jaacks (changes since v.1.3.0) ***************************************************************

/* 
The following file (general functions.ahk) must be included in the directory of the script - if you compile to exe, then you won't need it since it is built into it.
the file was taken from the midiout thread on ahk forum: http://www.autohotkey.com/forum/topic18711.html
*/

#Include general functions.ahk
#SingleInstance force
#MaxHotkeysPerInterval 400		; higher interval needed when using a continous controller like the Griffin PowerMate
#NoEnv
OnExit, ShutApp

;=================== Define Variables ===================

  IniRead, Channel, config.ini, Midiport, MidiChannel       			; midi channel for sending midi data to Total Mix from the config file
  IniRead, VolCC, config.ini, Midiport, MidiCC		       			; midi cc # for volume on Total Mix from the config file
  IniRead, CCIntVal, config.ini, Volume, LastValue				; This restores the last volume value from the config file
  IniRead, VolumeStepVal, config.ini, Volume, VolumeStep			; This value from the config file adjusts the value change when pressing the Volume buttons
  IniRead, VolumeMaxVal, config.ini, Volume, MaxValue			; Maximum volume
  IniRead, HideTrayIconVal, config.ini, Settings, HideTrayIcon			; set in the config file (1 hides Tray Icon, 0 shows)
  IniRead, vol_DisplayTime, config.ini, OSD, DisplayTime				; How long to display the volume level bar graph
  IniRead, vol_CBM, config.ini, OSD, Color								; Volume Bar color (see the help file to use more precise shades)
  IniRead, vol_CW, config.ini, OSD, BackgroundColor						; Volume Bar background color
  IniRead, vol_PosX, config.ini, OSD, PosX								; Volume Bar's horizontal screen position.  Use -1 to center the bar in that dimension:
  IniRead, vol_PosY, config.ini, OSD, PosY								; Volume Bar's vertical screen position.  Use -1 to center the bar in that dimension:
  IniRead, vol_Width, config.ini, OSD, Width							; width of Volume Bar
  IniRead, vol_Thick, config.ini, OSD, Height							; thickness of Volume Bar
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

#SingleInstance
SetBatchLines, 10ms
  
;=================== Select MIDI Port ===================

NumPorts := MidiOutsEnumerate()  											; count the amount of installed MIDI ports and write into variable "NumPorts"
  
Loop, %  NumPorts															; repeat this loop until the end of NumPorts is reached
{
Port := A_Index -1															; assign MIDI port ID -1 to variable "Port" (MIDI ports start counting at 0)
PortList .= "ID " . Port . ": " MidiOutPortName%Port% "|"					; create the different dropdownlist entries seperated with a "|"
}

IniRead, SelectedMidiPort, config.ini, Midiport, Device						; read previously stored MIDI port from config.ini

OpenCloseMidiAPI()															; do some midi work by opening port for the messages to pass
h_midiout := midiOutOpen(SelectedMidiPort-1) 								; open the stored MIDI port for communication

;=================== Define Hotkey Triggers ===================

IniRead, EnterVolumeUpHotkey, config.ini, Hotkeys, VolumeUpHotkey			; read setting from config.ini and write it into variable "EnterVolumeUpHotkey"
IniRead, EnterVolumeDownHotkey, config.ini, Hotkeys, VolumeDownHotkey		; read setting from config.ini and write it into variable "EnterVolumeDownHotkey"
IniRead, EnterVolumeMuteHotkey, config.ini, Hotkeys, VolumeMuteHotkey		; read setting from config.ini and write it into variable "EnterVolumeMuteHotkey"														; read hotkeys from config.ini		
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
Gui, Add, Text, x30 y80 w110 h20 , Volume Up Hotkey												; text
Gui, Add, Hotkey, x160 y80 w210 h20 vEnterVolumeUpHotkey, %EnterVolumeUpHotkey%					; show assigned hotkey in input field and write new input to EnterVolumeUpHotkey on Submit

;******* volume down hotkey assignment *******
Gui, Add, Text, x30 y120 w110 h20 , Volume Down Hotkey											; text
Gui, Add, Hotkey, x160 y120 w210 h20 vEnterVolumeDownHotkey, %EnterVolumeDownHotkey%			; show assigned hotkey in input field and write new input to EnterVolumeDownHotkey on Submit

;******* volume mute hotkey assignment *******
Gui, Add, Text, x30 y160 w110 h20 , Volume Mute Hotkey											; text	
Gui, Add, Hotkey, x160 y160 w210 h20 vEnterVolumeMuteHotkey, %EnterVolumeMuteHotkey%			; show assigned hotkey in input field and write new input to EnterVolumeMuteHotkey on Submit

;******* midi device selection *******
Gui, Add, DropDownList,% "x162 y200 w210 AltSubmit vMIDIPorts", %PortList% 						; create list entries from "PortList" and copy to "MIDIPorts"
GuiControl, Choose, MIDIPorts, %SelectedMIDIPort%												; show selected entry in the dropdown list
Gui, Add, Text, x32 y200 w110 h20 , MIDI-Port													; text
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
IniWrite, %EnterVolumeUpHotkey%, config.ini, Hotkeys, VolumeUpHotkey							; write hotkey settings to config.ini
IniWrite, %EnterVolumeDownHotkey%, config.ini, Hotkeys, VolumeDownHotkey						; write hotkey settings to config.ini
IniWrite, %EnterVolumeMuteHotkey%, config.ini, Hotkeys, VolumeMuteHotkey						; write hotkey settings to config.ini
Hotkey, %EnterVolumeUpHotkey%, VolumeUp															; re-assign hotkeys with saved value
Hotkey, %EnterVolumeDownHotkey%, VolumeDown														; re-assign hotkeys with saved value
Hotkey, %EnterVolumeMuteHotkey%, VolumeMute														; re-assign hotkeys with saved value
IniWrite, %MIDIPorts%, config.ini, Midiport, Device												; write port value to config.ini
IniRead, SelectedMidiPort, config.ini, Midiport, Device											; re-read saved MIDI port from config.ini
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
IniWrite, %CCIntVal%, config.ini, Volume, LastValue
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
	midiOutShortMsg(h_midiout, "CC", Channel, VolCC, CCIntVal)
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
	midiOutShortMsg(h_midiout, "CC", Channel, VolCC, CCIntVal)
	Gosub, vol_ShowBars 
return

;********* volume mute command *************

VolumeMute:
If MuteState = 0
	{
	MuteState:= 1
	CCIntValMute:= CCIntVal
	CCIntVal:= 0
	midiOutShortMsg(h_midiout, "CC", Channel, VolCC, CCIntVal)
	Gosub, vol_ShowBars
	return
	}
If MuteState = 1
	{
	MuteState:= 0
	CCIntVal:= CCIntValMute
	midiOutShortMsg(h_midiout, "CC", Channel, VolCC, CCIntVal)
	Gosub, vol_ShowBars
	return
	}
return

vol_ShowBars:
CCIntValOSD := (CCIntVal/VolumeMaxVal)*100
IfWinNotExist, CCIntValOSD		; To prevent the "flashing" effect, only create the bar window if it doesn't already exist.
{
	Progress, %vol_BarOptions%, , , CCIntValOSD
}
Progress, 1:%CCIntValOSD%		; Get volume %.
SetTimer, vol_BarOff, %vol_DisplayTime%
return

vol_BarOff:
SetTimer, vol_BarOff, off
Progress, 1:Off
return

midiOutClose(h_midiout) 										; stop midi output
OpenCloseMidiAPI()
