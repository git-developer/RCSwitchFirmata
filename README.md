# RCSwitchFirmata

## Description
*RCSwitchFirmata* is an Arduino sketch that combines [ConfigurableFirmata](https://github.com/firmata/ConfigurableFirmata) and [rc-switch](https://github.com/sui77/rc-switch). It comes with an integration into [FHEM](http://fhem.de).

RCSwitchFirmata allows you to use a single Arduino for multiple purposes, including radio transmissions. For example, you can read digital inputs, control a relais and switch radio outlets with a single Arduino today. You could extend that to receive the temperature from your weather station tomorrow, without a change to the Arduino sketch.

[Firmata](https://github.com/firmata/arduino) is a protocol for communicating with microcontrollers from software on a host computer. [ConfigurableFirmata](https://github.com/firmata/ConfigurableFirmata) is a plugin-based version of Firmata which allows to read and control an Arduino from a host computer without changes to the Arduino firmware.

[rc-switch](https://github.com/sui77/rc-switch) is a library for sending and receiving signals to radio controlled devices.

## Hardware configuration
###Requirements

* Any host machine (e.g. your computer)
* Any Arduino (e.g. an Arduino Nano)
* Any RF sender to send RF signals (e.g. FS1000A)
* Any RF receiver to receive RF signals (e.g. RXB6)

###Setup
1. Connect the sender to an arbitrary pin.
2. Connect the receiver to a pin that supports interrupts (depending on your Arduino model, usually pins 2 & 3).
3. Connect the Arduino to the host.

## Arduino configuration
###Requirements
* Arduino IDE
* Directory `arduino/libraries` from this project

###Setup
1. Copy the content of the project directory `arduino/libraries` into your Arduino library folder.
 * On Windows and Mac, this is the Documents folder in your user home directory, e.g. `My Documents/Arduino/libraries` 
 * On Linux, this is `Sketchbook/libraries` in your user home directory.
1. Open the RCSwitchFirmata sketch in the Arduino IDE and configure it according to your needs.
1. Upload the sketch to your Arduino.

Firmata features can be en-/disabled by in-/excluding the corresponding header in the RCSwitchFirmata sketch.

#### FirmataExt
*FirmataExt* must be enabled because it is required for communication between host and Arduino. It is enabled by default:

 ```
#include <utility/FirmataExt.h>
FirmataExt firmataExt;
```

#### RCOutputFirmata
RCOutputFirmata is required to send. It is enabled by default:

```
#include <RCSwitch.h> //wouldn't load from RCOutputFirmata.h in Arduino1.0.3
#include <utility/RCOutputFirmata.h>
RCOutputFirmata rcOutput;
```

#### RCInputFirmata
RCInputFirmata is required to receive. It is enabled by default:

```
#include <RCSwitch.h> //wouldn't load from RCInputFirmata.h in Arduino1.0.3
#include <utility/RCInputFirmata.h>
RCInputFirmata rcInput;
```

#### Other Firmata features
You may disable any Firmata feature to save memory. For example, if you don't need analog outputs:

```
//#include <utility/AnalogOutputFirmata.h>
AnalogOutputFirmata analogOutput;
```

## FHEM configuration
###Requirements
1. A working FHEM installation in version 5.5 or higher
2. Directory `FHEM` from this project

###Setup
1. Copy the project directory `FHEM` into the root directory of your FHEM installation.
1. Add a device for Firmata
1. To send, add a device for the sender
1. To receive, add a device for the receiver

###Example

Now let's say you want to switch an Intertechno socket outlet.

* Your Arduino is connected to `/dev/ttyUSB0`,
* RF sender module is connected to pin 11,
* RF receiver module is connected to pin 2

####RCSwitch Configuration

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

## Known problems
###Signal quality
The signal quality depends on the quality of the RF modules and the antenna.

* Each RF module should have an antenna with a length of λ = c<sub>0</sub>/f (speed of light divided by frequency) or a fraction of it. An effective and cheap antenna is a copper wire with the length of λ/4, e.g. 17.4 cm for 433 MHz.
* Even very cheap senders (XY-FST, FS1000A) have shown good results.
* For best results, a superheterodyne receiver (RXB6) is recommended. Very cheap receivers (XY-MK-5V) may work, but this depends on the environment and the sensitivity of controlled devices.

###Build environment
RCSwitchFirmata was developed on and works with [Arduino IDE 1.5.6-r2](https://www.arduino.cc/en/Main/OldSoftwareReleases#1.5.x). It seems that in later versions of the IDE, the include mechanism was changed, causing compile errors. This problem occurs at least on version 1.5.8 & 1.6.4.

## Project status
This project was developed on the FHEM forum in 2014 and moved to GitHub in 2015.

## History
See the thread [FHEM+Arduino Firmata via Ethernet+RF 433 Mhz Sender+Baumarkt-Funksteckdosen](http://forum.fhem.de/index.php/topic,22320.0.html) for details about the development of this project.

## Links
* [FHEM+Arduino Firmata via Ethernet+RF 433 Mhz Sender+Baumarkt-Funksteckdosen](http://forum.fhem.de/index.php/topic,22320.0.html)
* [Arduino Firmata  in FHEM](http://www.fhemwiki.de/wiki/Arduino_Firmata)
* [Firmata](https://github.com/firmata/arduino)
* [rc-switch on Google Code](https://code.google.com/p/rc-switch/)
* [rc-switch on GitHub](https://github.com/sui77/rc-switch)
