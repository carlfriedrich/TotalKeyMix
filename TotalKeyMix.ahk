;=================== Total Control 1.0 ===================
;****************** Control the volume on the Total Mix application of the RME soundcards via computer keyboard ***************

/* 

The following file (general functions.ahk) must be included in the directory of the script - if you compile to exe, then you won't need it since it is built into it.
the file was taken from the midiout thread on ahk forum: http://www.autohotkey.com/forum/topic18711.html
*/



#Include general functions.ahk
#SingleInstance force
#NoEnv



;============= Define variables =================================
    
  Channel  := 1        			; midi channel for sending midi data to Total Mix
  Note 	   := 60           		; midi number for middle C
  NoteDur  := 100				; note duration
  VolCC    := 7       			; cc # for volume on Total Mix
  CCIntVal := 127      			; This is the starting value to change the volume
  Speed    := 1       			; This value will make the value change slower or faster. Increase the number to make value change slower
  MuteState:= 0					; default mute state = off
  ToggleSetup:= 0				; toggle state of the setup GUI

  
;======================= select midi port ========================

NumPorts := MidiOutsEnumerate()  											; count the amount of installed MIDI ports
  
Loop, %  NumPorts															; loop this action until the end of NumPorts is reached
{
Port := A_Index -1															; assign MIDI port ID -1 to variable "Port"
PortList .= "ID " . Port . ": " MidiOutPortName%Port% "|"					; create the different dropdownlist entries seperated with a |
}

IniRead, SelectedMidiPort, config.ini, Midiport, Device						; read saved MIDI port from config.ini

;Do some midi work by opening port for the messages to pass.
OpenCloseMidiAPI()
h_midiout := midiOutOpen(SelectedMidiPort) 


;============== define hotkey triggers ========================
IniRead, EnterVolumeUpHotkey, config.ini, Hotkeys, VolumeUpHotkey			; read setting from config.ini
IniRead, EnterVolumeDownHotkey, config.ini, Hotkeys, VolumeDownHotkey		; read setting from config.ini
IniRead, EnterVolumeMuteHotkey, config.ini, Hotkeys, VolumeMuteHotkey		; read setting from config.ini																; read hotkeys from config.ini		
Hotkey, %EnterVolumeUpHotkey%, VolumeUp 									; assign retrieved value from config.ini to hotkey
Hotkey, %EnterVolumeDownHotkey%, VolumeDown									; assign retrieved value from config.ini to hotkey
Hotkey, %EnterVolumeMuteHotkey%, VolumeMute									; assign retrieved value from config.ini to hotkey


;==================== setup gui ============================

Menu, Tray, NoStandard														; don't show the default ahk menu on the tray
Menu, Tray, Icon, volume.ico								
Menu, Tray, Add, Setup, GuiShow												; add menu entry "Setup"
Menu, Tray, Add																; add seperator
Menu, Tray, Add, Exit, QuitScript											; add menu entry "Exit"

Menu, Tray, Default, Setup													; default action on left click = "Setup"
Menu, Tray, Click, 1														; left click
Return

QuitScript:
 ExitApp
Return

GuiShow:
if ToggleSetup = 0
{
ToggleSetup = 1																					; set toggle variable to "setup is shown"
   
Gui, Add, Text, x152 y20 w130 h20 +Center, Total Control Setup 									; text

;******* volume up hotkey assignment *******
Gui, Add, Text, x30 y80 w110 h20 , Volume Up Hotkey												; text
Gui, Add, Hotkey, x160 y80 w210 h20 vEnterVolumeUpHotkey, %EnterVolumeUpHotkey%					; assign value from config.ini to hotkey

;******* volume down hotkey assignment *******
Gui, Add, Text, x30 y120 w110 h20 , Volume Down Hotkey											; text
Gui, Add, Hotkey, x160 y120 w210 h20 vEnterVolumeDownHotkey, %EnterVolumeDownHotkey%			; assign value from config.ini to hotkey

;******* volume mute hotkey assignment *******
Gui, Add, Text, x30 y160 w110 h20 , Volume Mute Hotkey											; text	
Gui, Add, Hotkey, x160 y160 w210 h20 vEnterVolumeMuteHotkey, %EnterVolumeMuteHotkey%			; assign value from config.ini to hotkey

;******* midi device selection *******
Gui, Add, DropDownList,% "x162 y200 w210 AltSubmit vSelectedPort Choose", %PortList% 			; chose MIDI port
Gui, Add, Text, x32 y200 w110 h20 , MIDI-Port													; text
Gui, Add, Button, x252 y310 w110 h30 , OK 														; create ok button
Gui, Add, Button, x62 y310 w100 h30 , Cancel 													; create cancel button
Gui, Show, x304 y135 h396 w427, Total Control Setup 											; show GUI
Return
}


Else
{
   ToggleSetup = 0																				; set toggle variable to "setup hidden"
   Gui, destroy
}
Return


;******* ok button function *******
ButtonOK:
Gui, Submit																						; submit changed values in GUI
IniWrite, %EnterVolumeUpHotkey%, config.ini, Hotkeys, VolumeUpHotkey							; write hotkey settings to config.ini
IniWrite, %EnterVolumeDownHotkey%, config.ini, Hotkeys, VolumeDownHotkey						; write hotkey settings to config.ini
IniWrite, %EnterVolumeMuteHotkey%, config.ini, Hotkeys, VolumeMuteHotkey						; write hotkey settings to config.ini
Hotkey, %EnterVolumeUpHotkey%, VolumeUp															; re-assign hotkeys with saved value
Hotkey, %EnterVolumeDownHotkey%, VolumeDown														; re-assign hotkeys with saved value
Hotkey, %EnterVolumeMuteHotkey%, VolumeMute														; re-assign hotkeys with saved value
SelectedPort-=1																					; actual selected port number -1
IniWrite, %SelectedPort%, config.ini, Midiport, Device											; write port value to config.ini
IniRead, SelectedMidiPort, config.ini, Midiport, Device											; re-read saved MIDI port from config.ini
ToggleSetup = 0																					; set toggle variable to "setup hidden"
Gui, destroy
Return

;******* cancel button function *******
ButtonCancel:
ToggleSetup = 0																					; set toggle variable to "setup hidden"
Gui, destroy
Return


GuiClose:
ExitApp




;========== Define keys for midi output CC value =============


;******* volume up command ********  

VolumeUp:
Loop 
{ 
	CCIntVal := CCIntVal < 127 ? CCIntVal+1 : 127              	; check for max value reached.
	midiOutShortMsg(h_midiout, "CC", Channel, VolCC, CCIntVal) 	; midi "CC" message(definded in general funtions.ahk)on Channel(definded above),VolCC,CCIntVal in vars above 
	Sleep, %Speed%                                           	; repeat speed
	if !GetKeyState(EnterVolumeUpHotkey,"P") 					; if not, or, if key is released 
	break 
} 
Return



; ********* volume down command *************

VolumeDown: 
Loop 
{
	CCIntVal := CCIntVal > 0 ? CCIntVal-1 : 0                 	; check min value reached.
	midiOutShortMsg(h_midiout, "CC", Channel, VolCC, CCIntVal) 
	Sleep, %Speed%          									; repeat speed
	if !GetKeyState(EnterVolumeDownHotkey,"P") 					; if not, or, if key is released 
	break 
} 
Return


; ********* volume mute command *************

VolumeMute:
{
 midiOutShortMsg(h_midiout, "N1", 1, 93, 127)     				; send note on event on A5 
  Sleep %NoteDur%												; repeat speed
  midiOutShortMsg(h_midiout, "N0", 1, 93, 0)					; send note off event on A5 
exit
}
Return

midiOutClose(h_midiout) 										; stop midi output
OpenCloseMidiAPI()
