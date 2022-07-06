;;;;;;;;; AHK functions for midi output by calling winmm.dll ;;;;;;;;;;
;http://msdn.microsoft.com/library/default.asp?url=/library/en-us/multimed/htm/_win32_multimedia_functions.asp

OpenCloseMidiAPI() {  ; at the beginning to load, at the end to unload winmm.dll
   Static hModule
   If hModule
      DllCall("FreeLibrary", UInt,hModule), hModule := ""
   If (0 = hModule := DllCall("LoadLibrary",Str,"winmm.dll")) {
      MsgBox Cannot load libray winmm.dll
      Exit
   }
}

;;;;;;;;;;;;;;; Functions for Sending Individual Messages ;;;;;;;;;;;;;;;

midiOutOpen(uDeviceID = 0) { ; Open midi port for sending individual midi messages --> handle
   strh_midiout = 0000

   result := DllCall("winmm.dll\midiOutOpen", UInt,&strh_midiout, UInt,uDeviceID, UInt,0, UInt,0, UInt,0, UInt)
   If (result or ErrorLevel) {
      MsgBox There was an error opening the midi port.`nError code %result%`nErrorLevel = %ErrorLevel%
      Return -1
   }
   Return UInt@(&strh_midiout)
}

midiOutShortMsg(h_midiout, EventType, Channel, Param1, Param2) {
  ;h_midiout: handle to midi output device returned by midiOutOpen
  ;EventType, Channel combined -> MidiStatus byte: http://www.harmony-central.com/MIDI/Doc/table1.html
  ;Param3 should be 0 for PChange, ChanAT, or Wheel
  ;Wheel events: entire Wheel value in Param2 - the function splits it into two bytes

  If (EventType = "NoteOn" OR EventType = "N1")
     MidiStatus := 143 + Channel
  Else If (EventType = "NoteOff" OR EventType = "N0")
     MidiStatus := 127 + Channel
  Else If (EventType = "CC")
     MidiStatus := 175 + Channel
  Else If (EventType = "PolyAT"  OR EventType = "PA")
     MidiStatus := 159 + Channel
  Else If (EventType = "ChanAT"  OR EventType = "AT")
     MidiStatus := 207 + Channel
  Else If (EventType = "PChange" OR EventType = "PC")
     MidiStatus := 191 + Channel
  Else If (EventType = "Wheel"   OR EventType = "W") {
     MidiStatus := 223 + Channel
     Param2 := Param1 >> 8      ; MSB of wheel value
     Param1 := Param1 & 0x00FF  ; strip MSB
  }
  result := DllCall("winmm.dll\midiOutShortMsg", UInt,h_midiout, UInt, MidiStatus|(Param1<<8)|(Param2<<16), UInt)
  If (result or ErrorLevel)  {
    MsgBox There was an error sending the midi event: (%result%`, %ErrorLevel%)
    Return -1
  }
}

midiOutClose(h_midiout) {  ; Close MidiOutput
  Loop 9 {
     result := DllCall("winmm.dll\midiOutClose", UInt,h_midiout)
     If !(result or ErrorLevel)
        Return
     Sleep 250
  }
  MsgBox Error in closing the midi output port. There may still be midi events being processed.
  Return -1
}

;;;;;;;;;;;;;;; Functions for Stream Output ;;;;;;;;;;;;;;;

midiStreamOpen(DeviceID) { ; Open the midi port for streaming
  ;MMRESULT    midiStreamOpen( --> handle to midi stream, used by midi stream out functions
  ;LPHMIDISTRM lphStream,  Pointer to handle to stream - filled by call to midiStreamOpen
  ;LPUINT      puDeviceID, Pointer to DeviceID
  ;DWORD       cMidi,      Always 1
  ;DWORD_PTR   dwCallback, Pointer to callback function, event, etc. (0 = none)
  ;DWORD_PTR   dwInstance, Number you can assign to this stream
  ;DWORD       fdwOpen)    Type of callback

  VarSetCapacity(strh_stream, 4, 0)
  result:=DllCall("winmm.dll\midiStreamOpen", UInt,&strh_stream, UIntP,DeviceID, UInt,1, UInt,0, UInt,0, UInt,0, UInt)
  If (result or ErrorLevel) {
     MsgBox There was an error opening the midi port.`nError code %result%`nErrorLevel = %ErrorLevel%
     Return -1
  }
  Return UInt@(&strh_stream)
}

AddEventToBuffer(ByRef MidiBuffer, DeltaTime, EventType, Channel, Param1, Param2, NewBuffer = 0) {
; MIDIEVENT Structure
;    DWORD dwDeltaTime; offset to time this event should be sent
;    DWORD dwStreamID;  streamID this should be sent to (assumed to always be 0 for our purposes)
;    DWORD dwEvent;     Event DWord (Highest byte is EventCode [shortMsg for us], followed by param2, param1, status)
;    DWORD dwParms[];   not needed for short messages
; BufferSize = 12 * number of events

  Static BufOffset = 0     ; keep track of where in the buffer the next event goes
  If (NewBuffer)
     BufOffset = 0

  If (BufOffset + 12 > VarSetCapacity(MidiBuffer)) {
     MsgBox Midi Buffer is full.`nEvent %EventType% %Channel% %Param1% %Param2%`n could not be added.
     Return -1
  }

  If (EventType = "NoteOn" OR EventType = "N1")  ; Calc MidiStatus byte (~ midiOutShortMsg Function)
    MidiStatus := 143 + Channel
  Else if (EventType = "NoteOff" OR EventType = "N0")
    MidiStatus := 127 + Channel
  Else if (EventType = "CC")
    MidiStatus := 175 + Channel
  Else if (EventType = "PolyAT"  OR EventType = "PA")
    MidiStatus := 159 + Channel
  Else if (EventType = "ChanAT"  OR EventType = "AT")
    MidiStatus := 207 + Channel
  Else if (EventType = "PChange" OR EventType = "PC")
    MidiStatus := 191 + Channel
  Else if (EventType = "Wheel"   OR EventType = "W") {
    MidiStatus := 223 + Channel
    Param2 := Param1 >> 8
    Param1 := Param1 & 0x00FF
  }
  Else {
    MsgBox Invalid EventType.
    Return -1
  }

  PokeInt(DeltaTime, &MidiBuffer+BufOffset)
  PokeInt(0, &MidiBuffer+BufOffset+4)
  PokeInt(MidiStatus|(Param1 << 8)|(Param2 << 16), &MidiBuffer+BufOffset+8)
  BufOffset += 12
}

SetTempoAndTimebase(h_stream, BPM, PPQ) { ; BPM = tempo in Beats Per Minute, PPQ = ticks (Parts) Per Quarter note
  VarSetCapacity(struct, 8) ; structure
  PokeInt( 8,   &struct)    ; always = 8 (?)
  PokeInt(PPQ,  &struct+4)  ; contains number of ticks per quarter note

  result := DllCall("winmm.dll\midiStreamProperty", UInt,h_stream, UInt,&struct
         ,  UInt,0x80000001, UInt)   ; flags = MIDIPROPSET (0x80000000) and MIDIPROP_TIMEDIV (1)
  If (result) {
    MsgBox Error %result% in setting the Timebase
    Return -1
  }

  PokeInt(6.e7//BPM,&struct+4) ; dwTempo as microseconds per quarter note
  result := DllCall("winmm.dll\midiStreamProperty", UInt,h_stream, UInt,&struct
         ,  UInt,0x80000002, UInt)   ; flags = MIDIPROPSET (0x80000000) and MIDIPROP_TEMPO (2)
  If (result) {
    MsgBox Error %result% in setting the Tempo
    Return -1
  }
}

;MIDIHDR struct
;    LPSTR      lpData;                 pointer to midi data stream
;    DWORD      dwBufferLength;         size of buffer
;    DWORD      dwBytesRecorded;        number of bytes of actual midi data in buffer
;    DWORD_PTR  dwUser;                 custom user data
;    DWORD      dwFlags;                should be 0
;    struct midihdr_tag far * lpNext;   do not use
;    DWORD_PTR  reserved;               do not use
;    DWORD      dwOffset;               offset generated by callback - not used in this routine
;    DWORD_PTR  dwReserved[4];          do not use

midiOutputBuffer(h_stream, ByRef MidiBuffer, BufSize, BufDur) { ; Play Midi Buffer... Buf-fer Dur-ation in ms
  Global MIDIHDR      ; other functions can access MIDIHDR
  VarSetCapacity(MIDIHDR, 36, 0)
  PokeInt(&MidiBuffer,&MIDIHDR)
  PokeInt(BufSize,    &MIDIHDR+4)
  PokeInt(BufSize,    &MIDIHDR+8) ; remaining props can all be 0

  result := DllCall("winmm.dll\midiOutPrepareHeader", UInt,h_stream, UInt,&MIDIHDR, UInt,36, UInt) ; 36 = size of header
  If (result)  {
    MsgBox Error %result% in midiOutPrepareHeader
    Return -1
  }
  result := DllCall("winmm.dll\midiStreamOut", UInt,h_stream, UInt,&MIDIHDR, UInt,36, UInt) ; Queue up buffer, ready to play
  If (result)  {
    MsgBox Error %result% in midiStreamOut
    Return -1
  }
  result := DllCall("winmm.dll\midiStreamRestart", UInt,h_stream, UInt) ; Start playback
  If (result) {
    MsgBox Error %result% in midiStreamRestart
    Return -1
  }

  Sleep %BufDur% ; Wait for duration of entire buffer

  DllCall("winmm.dll\midiStreamStop", UInt, h_stream) ; Stop Stream - keeps it from sleep.
}

midiOutCloseStream(h_stream, ByRef MIDIHDR) { ; unprepare header and close stream
  result := DllCall("winmm.dll\midiOutUnprepareHeader", UInt,h_stream, UInt,&MIDIHDR, UInt,36, UInt)
  If (result) {
    MsgBox Error %result% in midiOutUnprepareHeader
    Return -1
  }
  result := DllCall("winmm.dll\midiStreamClose", UInt,h_stream, UInt) ; CloseMidiStream
  If (result)  {
    MsgBox Error %result% in midiStreamClose
    Return -1
  }
}

;;;;;;;;;;;;;;; Utility Functions ;;;;;;;;;;;;;;;

MidiOutGetNumDevs() { ; Get number of midi output devices on system, first device has an ID of 0
  Return DllCall("winmm.dll\midiOutGetNumDevs")
}

MidiOutNameGet(uDeviceID = 0) { ; Get name of a midiOut device for a given ID
;MIDIOUTCAPS struct
;    WORD      wMid;
;    WORD      wPid;
;    MMVERSION vDriverVersion;
;    CHAR      szPname[MAXPNAMELEN];
;    WORD      wTechnology;
;    WORD      wVoices;
;    WORD      wNotes;
;    WORD      wChannelMask;
;    DWORD     dwSupport;

  VarSetCapacity(MidiOutCaps, 50, 0)  ; allows for szPname to be 32 bytes
  OffsettoPortName := 8, PortNameSize := 32
  result := DllCall("winmm.dll\midiOutGetDevCapsA", UInt,uDeviceID, UInt,&MidiOutCaps, UInt,50, UInt)
  If (result OR ErrorLevel) {
    MsgBox Error %result% (ErrorLevel = %ErrorLevel%) in retrieving the name of midi output %uDeviceID%
    Return -1
  }
  VarSetCapacity(PortName, PortNameSize)
  DllCall("RtlMoveMemory", Str,PortName, Uint,&MidiOutCaps+OffsettoPortName, Uint,PortNameSize)
  Return PortName
}

MidiOutsEnumerate() { ; Returns number of midi output devices, creates global array MidiOutPortName with their names
  Local NumPorts, PortID
  MidiOutPortName =
  NumPorts := MidiOutGetNumDevs()

  Loop %NumPorts% {
    PortID := A_Index -1
    MidiOutPortName%PortID% := MidiOutNameGet(PortID)
  }
  Return NumPorts
}

UInt@(ptr) {
   Return *ptr | *(ptr+1) << 8 | *(ptr+2) << 16 | *(ptr+3) << 24
}

PokeInt(p_value, p_address) { ; Windows 2000 and later
   DllCall("ntdll\RtlFillMemoryUlong", UInt,p_address, UInt,4, UInt,p_value)
}
