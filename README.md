# RCSwitchFirmata

## Quick start
- Connect RF sender and/or receiver to your Arduino board
- Install Arduino IDE
- Install Arduino libraries [ConfigurableFirmata v2.10.0](https://github.com/firmata/ConfigurableFirmata/releases/tag/2.10.0), [rc-switch v2.5.2](https://github.com/sui77/rc-switch/releases/tag/v2.52) and [RCSwitchFirmata v2.0.0](https://github.com/git-developer/RCSwitchFirmata/releases/tag/v2.0.0)
- Upload `RCSwitchFirmata.ino`
- Add the RCSwitchFirmata repository to your FHEM installation and update FHEM. Repository URL: `https://raw.githubusercontent.com/git-developer/RCSwitchFirmata/v2.0.0/FHEM/controls_frm_rc.txt`

## Compatibility
The current implementation, version 2.0.0, is compatible to
- ConfigurableFirmata [2.10.0](https://github.com/firmata/ConfigurableFirmata/releases/tag/2.10.0)
- rc-switch [2.5.2](https://github.com/sui77/rc-switch/releases/tag/v2.52)
- FHEM 5.8 updated to 2018-01-06 ([SVN revision 15794](https://svn.fhem.de/trac/browser/trunk/fhem/FHEM/10_FRM.pm?rev=15794))

FHEM before 2018-01-06 does not support Firmata versions newer than 2.6.

When rc-switch [2.6.0](https://github.com/sui77/rc-switch/releases/tag/2.6.0) or newer is used, sending of tristate codes seems not to work; sending of long codes is possible, however.

## Description
[RCSwitchFirmata](https://github.com/git-developer/RCSwitchFirmata) is an adapter between [ConfigurableFirmata](https://github.com/firmata/ConfigurableFirmata) and the [rc-switch](https://github.com/sui77/rc-switch) library. It comes with an integration into [FHEM](http://fhem.de).

RCSwitchFirmata allows you to use a single Arduino for multiple purposes, including radio transmissions. For example, you can read digital inputs, control a relais and switch radio outlets with a single Arduino today. You could extend that to receive the temperature from your weather station tomorrow, without a change to the Arduino sketch.

[Firmata](https://github.com/firmata/arduino) is a protocol for communicating with microcontrollers from software on a host computer.
[ConfigurableFirmata](https://github.com/firmata/ConfigurableFirmata) is a plugin-based version of Firmata which allows to read and control an Arduino from a host computer without changes to the Arduino firmware.
[rc-switch](https://github.com/sui77/rc-switch) is a library for sending and receiving signals to radio controlled devices.

## Hardware configuration
### Requirements

* Any host machine (e.g. your computer)
* Any Arduino (e.g. an Arduino Nano)
* Any RF sender to send RF signals (e.g. FS1000A)
* Any RF receiver to receive RF signals (e.g. RXB6)

### Setup
1. Connect the sender to an arbitrary pin.
2. Connect the receiver to a pin that supports interrupts (depending on your Arduino model, usually pins 2 & 3).
3. Connect the Arduino to the host.

## Arduino configuration
* Details: [arduino/libraries/RCSwitchFirmata/README.md](arduino/libraries/RCSwitchFirmata/README.md)
### Requirements
* Arduino IDE
* RCSwitchFirmata library (directory `arduino/libraries/RCSwitchFirmata` within this repository)

### Setup
1. Add RCSwitchFirmata, ConfigurableFirmata and rc-switch as arduino libraries, either with the Arduino IDE menu item *Add library...* or by copying them into your Arduino library folder.
   * On Windows and Mac, this is the Documents folder in your user home directory, e.g. `My Documents/Arduino/libraries`
   * On Linux, this is `Sketchbook/libraries` in your user home directory.
1. Copy the example sketch directory `examples/RCSwitchFirmata` to you Arduino sketch folder or a working directory.
1. Open the `RCSwitchFirmata.ino` sketch in the Arduino IDE and configure it according to your needs.
1. Connect your hardware to the pins of your Arduino board
    1. If you want to send RF signals: connect a RC sender to an arbitrary pin
    1. If you want to receive RF signals: connect a RC receiver to an interrupt-enabled pin
1. Connect your Arduino board to the host; save, compile and upload your `RCSwitchFirmata.ino` sketch
1. Connect your Firmata client software to the Arduino
    1. If you want to send RF signals: send an `RCOUTPUT_ATTACH` message to sender pin
    1. If you want to receive RF signals: send an `RCINPUT_ATTACH` message to receiver pin

Firmata features can be en-/disabled by in-/excluding the corresponding header in the `RCSwitchFirmata.ino` sketch. By default, all features are enabled. Microcontrollers with limited memory (< 16k) are not able to support all features simultaneously. To overcome this limitation, comment out the feature class declaration and associated include for any features that you do not need.

#### FirmataExt
*FirmataExt* must be enabled because it is required for communication between host and Arduino. It is enabled by default:

 ```C++
#include <utility/FirmataExt.h>
FirmataExt firmataExt;
```

#### RCOutputFirmata
RCOutputFirmata is required to send. It is enabled by default:

```C++
#include <utility/RCOutputFirmata.h>
RCOutputFirmata rcOutput;
```

#### RCInputFirmata
RCInputFirmata is required to receive. It is enabled by default:

```C++
#include <utility/RCInputFirmata.h>
RCInputFirmata rcInput;
```

#### Other Firmata features
You may disable any Firmata feature to save memory. For example, if you don't need analog outputs:

```C++
//#include <utility/AnalogOutputFirmata.h>
//AnalogOutputFirmata analogOutput;
```

## Host configuration
RCSwitchFirmata can be used with any client that supports [ConfigurableFirmata](https://github.com/firmata/ConfigurableFirmata), for example using one of the [Firmata Client Libraries](https://github.com/firmata/ConfigurableFirmata#firmata-client-libraries). This section contains example configurations for FHEM (which integrates [perl-firmata](https://github.com/ntruchsess/perl-firmata)) and [firmata.js](https://github.com/firmata/firmata.js).

### FHEM
* Details: [FHEM/README.md](FHEM/README.md)
#### Requirements
1. A working FHEM installation in version 5.5 or higher

#### Setup
1. Add the RCSwitchFirmata repository to your FHEM installation so that it will be included by the FHEM `update` command. To achieve this, enter the following command on the FHEM commandline once:
`update add https://raw.githubusercontent.com/git-developer/RCSwitchFirmata/v2.0.0/FHEM/controls_frm_rc.txt`
1. Update RCSwitchFirmata manually:
`update all https://raw.githubusercontent.com/git-developer/RCSwitchFirmata/v2.0.0/FHEM/controls_frm_rc.txt`
1. Add a device for Firmata
1. To send, add a device for the sender
1. To receive, add a device for the receiver

#### Example

Now let's say you want to switch an Intertechno socket outlet.

* Your Arduino is connected to `/dev/ttyUSB0`,
* RF sender module is connected to pin 11,
* RF receiver module is connected to pin 2

##### RCSwitchFirmata Configuration

```
define firmata FRM /dev/ttyUSB0@57600
define rc_sender FRM_RCOUT 11
attr   rc_sender IODev firmata
define rc_receiver FRM_RCIN 2
attr   rc_receiver IODev firmata
define switch IT 0FF00F0F0F 0F 00
attr   switch IODev rc_sender
```

To switch your socket, call `set switch on`. To send a tristate code directly without IT device, call `set sender tristateCode 0FF00F0F0F0F`. When you press a button on the remote of your socket, the device `rc_receiver` receives a message and the state of the IT device changes.

### JavaScript
This example is is based on [firmata.js](https://github.com/firmata/firmata.js). It was originally described in issue [#2](https://github.com/git-developer/RCSwitchFirmata/issues/2#issuecomment-437563401).

#### Send a message to the Arduino
```javascript
RC315.rcOutput = function(subcommand, pin, val) { // val is either a 2-byte value or a 7-bit encoded array
  var data = [];
  data.push(START_SYSEX);
  data.push(RCOUTPUT_DATA);
  data.push(subcommand);
  data.push(pin);
  if (val) {
    if (Array.isArray(val)) { // it is assumed that the array is already 7-bit encoded
      for (var i = 0; i < val.length ; i++) {
        data.push(val[i]);
      }
    } else {
      // encode 16-bit value into 7-bit message chunks
      data.push(val & 0x7F);
      val = val >> 7 ;
      data.push(val & 0x7F);
      val = val >> 7 ;
      data.push(val & 0x7F);
    }
  }
  data.push(END_SYSEX);
  this.board.sp.write(data);
};

RC315.rcControl = function(code, pulseLength) {
  this.rcOutput(RCOUTPUT_DETACH, outPin);
  this.rcOutput(RCOUTPUT_ATTACH, outPin);
  if (pulseLength) {
    this.rcOutput(RCOUTPUT_PULSE_LENGTH, outPin, pulseLength);
  }
  var bytes = Encoder7Bit.to7BitArray([0x18, 0x00].concat(longToByteArray(code)));
  this.rcOutput(RCOUTPUT_CODE_LONG, outPin,  bytes);
}
```

#### Receive a message from the Arduino
```javascript
// register a handler for RCINPUT_DATA messages
RC315.init = function() {
  this.board = new firmata.Board('COM4');
  firmata.SYSEX_RESPONSE[RCINPUT_DATA] = function(board) {
    console.log('RC315 in command (%s): %s, pin: %s ', new Date(), board.buffer[2], board.buffer[3]);
    if (board.buffer[2] == RCINPUT_MESSAGE) {
      var data = Encoder7Bit.from7BitArray(board.buffer.slice(4));
      console.log('value: %s, bitcount: %s, delay: %s, protocol: %s',
                  (data[0]<<24) + (data[1]<<16) + (data[2]<<8) + data[3],
                  (data[4]<<8) + data[5],
                  (data[6]<<8) + data[7],
                  (data[8]<<8) + data[9]);
    }
  }
}

// define a function to allow for RCINPUT configuration
RC315.rcinput = function(subcommand, pin, val) {
  var data = [];
  data.push(START_SYSEX);
  data.push(RCINPUT_DATA);
  data.push(subcommand);
  data.push(pin);
  data.push(END_SYSEX);
  this.board.sp.write(data);
};

// send an attach message to the arduino so that messages will be forwarded to firmata.SYSEX_RESPONSE[RCINPUT_DATA]
RC315.rcinput(RCINPUT_ATTACH, inPin)
```

## Known problems
### Signal quality
The signal quality depends on the quality of the RF modules and the antenna.

* Each RF module should have an antenna with a length of λ = c<sub>0</sub>/f (speed of light divided by frequency) or a fraction of it. An effective and cheap antenna is a copper wire with the length of λ/4, e.g. 17.4 cm for 433 MHz.
* Even very cheap senders (XY-FST, FS1000A) have shown good results.
* For best results, a superheterodyne receiver (RXB6) is recommended. Very cheap receivers (XY-MK-5V) may work, but this depends on the environment and the sensitivity of controlled devices.

### Build environment
RCSwitchFirmata was developed on and works with [Arduino IDE 1.8.4](https://www.arduino.cc/en/Main/OldSoftwareReleases). In earlier versions of the IDE, the include mechanism is different causing compile errors.

## Project status
This project was developed on the FHEM forum in 2014, moved to GitHub in 2015 and was updated to ConfigurableFirmata 2.10 in 2017.

## History
See the thread [FHEM+Arduino Firmata via Ethernet+RF 433 Mhz Sender+Baumarkt-Funksteckdosen](http://forum.fhem.de/index.php/topic,22320.0.html) for details about the development of this project.

## Links
* [FHEM+Arduino Firmata via Ethernet+RF 433 Mhz Sender+Baumarkt-Funksteckdosen](http://forum.fhem.de/index.php/topic,22320.0.html)
* [Arduino Firmata in FHEM](http://www.fhemwiki.de/wiki/Arduino_Firmata)
* [Firmata Protocol](https://github.com/firmata/protocol)
* [Firmata Implementation](https://github.com/firmata/arduino)
* [ConfigurableFirmata](https://github.com/firmata/ConfigurableFirmata)
* [rc-switch on GitHub](https://github.com/sui77/rc-switch)
* [rc-switch on Google Code](https://code.google.com/p/rc-switch/) (deprecated)
* [perl-firmata](https://github.com/jnsbyr/perl-firmata) with support for Firmata versions newer than 2.6
* [fhem-mirror/dev](https://github.com/ntruchsess/fhem-mirror/tree/dev) with support for Firmata versions newer than 2.6

## License
This library is free software; you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the Free Software Foundation; either version 2.1 of the License, or (at your option) any later version. See file `LICENSE` for further informations on licensing terms.
