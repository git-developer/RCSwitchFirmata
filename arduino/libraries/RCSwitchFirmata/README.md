# RCSwitchFirmata

[RCSwitchFirmata](https://github.com/git-developer/RCSwitchFirmata) is an adapter between [ConfigurableFirmata](https://github.com/firmata/ConfigurableFirmata) and the [RCSwitch](https://github.com/sui77/rc-switch) library.

It allows to send messages to and receive messages from radio controlled devices. Sender and receiver are referred to as *devices* within the context of this document. Multiple devices may be used at the same time; the only requirement is a pin per device. All devices may be used and configured independently. Thus, this document separates the main functions *send* and *receive*. RCSwitchFirmata is subdivided into *RCOutputFirmata* implementing the send function and *RCInputFirmata* implementing the receive function.

## Usage

1. Add RCSwitchFirmata, ConfigurableFirmata and RCSwitch as arduino libraries, either from the Arduino IDE menu item *Add library...* or by copying them into your Arduino library folder.
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

## Messages
All values described here are 8-bit-based (i.e., after unpacking from 7-bit sysex transfer format).
A common pattern of all queries is that they echo the query message as response. This pattern allows for detection of unsupported or wrong messages.

### Message format
- byte 0: Feature ID (`RCOUTPUT_DATA`or `RCINPUT_DATA`)
- byte 1: Subcommand
- byte 2: pin
- following bytes: subcommand specific parameters

### Send (RCOutputFirmata)
#### Query messages
| Subcommand                      | Description                                  | Value space                                | Default value                             |
| ------------------------------- | -------------------------------------------- | ------------------------------------------ | ----------------------------------------- |
| `RCOUTPUT_ATTACH`               | Configure a pin as RC sender                 | Arduino pin numbers                        |                                           |
| `RCOUTPUT_DETACH`               | Remove a pin as RC sender                    | Arduino pin numbers                        |                                           |
| `RCOUTPUT_PROTOCOL`             | Set the RCSwitch parameter `protocol`        | Defined by RCSwitch (RCSwitch 2.51: 1-3)   | Defined by RCSwitch (RCSwitch 2.51: 1)    |
| `RCOUTPUT_PULSE_LENGTH`         | Set the RCSwitch parameter `pulse length`    | Defined by RCSwitch (RCSwitch 2.51: `int`) | Defined by RCSwitch (RCSwitch 2.51: 350)  |
| `RCOUTPUT_REPEAT_TRANSMIT`      | Set the RCSwitch parameter `repeat transmit` | Defined by RCSwitch (RCSwitch 2.51: `int`) | Defined by RCSwitch (RCSwitch 2.51: 10)   |
| `RCOUTPUT_CODE_TRISTATE`        | Send a tristate code                         | `char[]`                                   |                                           |
| `RCOUTPUT_CODE_LONG`            | Send a long code                             | `long`                                     |                                           |
| `RCOUTPUT_CODE_CHAR`            | Send a character code                        | `char[]`                                   |                                           |
| `RCOUTPUT_CODE_TRISTATE_PACKED` | Send a tristate code                         | `byte[]`; every byte is composed of 4 tristate bits (defined as `RCOUTPUT_TRISTATE_?` constants in this file) | |                                           |

#### Query messages
- none

### Receive (RCInputFirmata)
#### Query messages
| Subcommand                      | Description                                  | Value space                                | Default value                             |
| ------------------------------- | -------------------------------------------- | ------------------------------------------ | ----------------------------------------- |
| `RCINPUT_ATTACH`                | Configure a pin as RC receiver               | Arduino pin numbers                        |                                           |
| `RCINPUT_DETACH`                | Remove a pin as RC receiver                  | Arduino pin numbers                        |                                           |
| `RCINPUT_TOLERANCE`             | RCSwitch value `receive tolerance`           | Defined by RCSwitch (RCSwitch 2.51: 0-100) | Defined by RCSwitch (RCSwitch 2.51: 60)   |
| `RCINPUT_ENABLE_RAW_DATA`       | Enable reporting of raw data                 | `boolean`                                  | `false`                                   |

#### Query messages
- bytes  0-3: received value (`long`)
- bytes  4-5: bitCount (`int`)
- bytes  6-7: delay (`int`)
- bytes  8-9: protocol (`int`)

If rawdata is enabled:
- bytes 10-(2*`RCSWITCH_MAX_CHANGES`): raw data (`int[]`)

## Links
- [Protocol details](https://github.com/firmata/protocol/blob/master/proposals/rcswitch-proposal.md)
- [RCSwitchFirmata](https://github.com/git-developer/RCSwitchFirmata)
- [ConfigurableFirmata](https://github.com/firmata/ConfigurableFirmata)
- [RCSwitch](https://github.com/sui77/rc-switch)
