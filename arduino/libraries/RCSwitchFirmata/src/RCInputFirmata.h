/*
  RCInputFirmata.h - Firmata library

  Version: 2.0.0-SNAPSHOT
  Author:  git-developer ( https://github.com/git-developer )

  Description
  -----------
   This library is an adapter between the firmata protocol and the RCSwitch
   library. It allows to receive radio messages.

  Usage
  -----
   1.) Connect a RC receiver to an interrupt-enabled pin of your Arduino board
   2.) Add RCSwitchFirmata, ConfigurableFirmata and RCSwitch as arduino libraries
   3.) Include RCInputFirmata in RCSwitchFirmata
   4.) Upload RCSwitchFirmata and connect Arduino to host
   5.) Send attach message to configure the pin as RC receiver

   On success, Arduino will report received messages to the host.
  
  Message format
  --------------
    Configuration messages:
     byte 0: subcommand
     byte 1: pin
     byte 2: subcommand specific parameter

    Reported messages:
     bytes  0-3: received value (long)
     bytes  4-5: bitCount (int)
     bytes  6-7: delay (int)
     bytes  8-9: protocol (int)
    if rawdata is enabled:
     bytes 10-(2*RCSWITCH_MAX_CHANGES): raw data (int[])

  Parameters
  ----------
    SETUP_ATTACH:
     Description:   Configure a pin as RC receiver
     Value space:   Arduino pin numbers

    SETUP_DETACH:
     Description:   Remove a pin as RC receiver
     Value space:   Arduino pin numbers

    CONFIG_TOLERANCE:
     Description:   RCSwitch receive tolerance
     Value space:   Defined by RCSwitch (RCSwitch 2.51: 0-100)
     Default value: Defined by RCSwitch (RCSwitch 2.51: 60)

    CONFIG_ENABLE_RAW_DATA:
     Description:   Enable reporting of raw data
     Value space:   boolean
     Default value: false

  Downloads
  ---------
   ConfigurableFirmata: https://github.com/firmata/arduino/tree/configurable
   RCSwitch:            https://code.google.com/p/rc-switch/

  License
  -------
   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2.1 of the License, or (at your option) any later version.

   See file LICENSE.txt for further informations on licensing terms.
*/

#ifndef RCInputFirmata_h
#define RCInputFirmata_h

#include <FirmataFeature.h>
#include <RCSwitch.h>

#define RCINPUT_DATA            0x5D // Sysex command: receive RC data

/* Subcommands */
#define UNKNOWN                 0x00

#define SETUP_ATTACH            0x01
#define SETUP_DETACH            0x02

#define CONFIG_TOLERANCE        0x31
#define CONFIG_ENABLE_RAW_DATA  0x32
#define MESSAGE                 0x41

#define NO_INTERRUPT -1

class RCInputFirmata:public FirmataFeature
{

public:
  boolean handlePinMode(byte pin, int mode);
  void handleCapability(byte pin);
  boolean handleSysex(byte command, byte argc, byte* argv);
  void reset();
  void report();

private:

  /** 1 receiver per pin */
  RCSwitch* receivers[TOTAL_PINS];

  /**
   * If set to true, received data will also be reported in raw format
   */
  boolean rawdataEnabled;


  /**
   * Initializes a receiver for a pin.
   *
   * @param pin Pin to associate to a receiver
   *
   * @return true in case of success
   */
  boolean attach(byte pin);

  /**
   * Removes the receiver from a pin.
   *
   * @param pin Pin that has a receiver associated
   */
  void detach(byte pin);

  /**
   * Send a message to the firmata host.
   *
   * @param subcommand Details about the message
   *                     (see the constants defined above)
   * @param pin        Pin that corresponds to the message
   */
  void sendMessage(byte subcommand, byte pin);

  /**
   * Send a message composed of two content blocks to the firmata host.
   * If only one content block is available, the length of the second
   * block must be set to 0.
   *
   * @param subcommand Details about the message
   *                     (see the constants defined above)
   * @param pin        Pin that corresponds to the message
   * @param length1    Length of first block of the message
   * @param data1      Content of first block of the message
   * @param length2    Length of second block of the message
   * @param data2      Content of second block of the message
   */
  void sendMessage(byte subcommand, byte pin, byte length1, byte *data1,
                                              byte length2, byte *data2);


  /**
   * Finds the interrupt number for a pin
   *
   * @param pin A pin
   *
   * @return the interrupt number for the given pin,
   *         or NO_INTERRUPT if the pin cannot be used for external interrupts
   */
  byte getInterrupt(byte pin);

};

#endif
