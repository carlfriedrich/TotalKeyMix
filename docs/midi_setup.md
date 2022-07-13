# MIDI Sonfiguration

## Virtual MIDI port

TotalKeyMix needs a virtual loopback MIDI driver like [LoopMidi][1] or
[LoopBe1][2] to be set up. This picture shows LoopMidi as an example:

![TotalMix MIDI In](loopmidi.png)

On the first start, add a new port via the "+" Button.

[1]: https://www.tobias-erichsen.de/software/loopmidi.html
[2]: https://nerds.de/en/loopbe1.html

## MIDI settings

The virtual loopback MIDI port has to be configured as MIDI In port in TotalMix:

![TotalMix MIDI In](totalmix_midi_in.png)

And as MIDI-Port in TotalKeyMix (accessible via tray icon):

![TotalKeyMix MIDI Port](totalkeymix_midi_port.png)

Furthermore, MIDI control has to be enabled in TotalMix:

![TotalMix MIDI Control](totalmix_midi_control.png)
