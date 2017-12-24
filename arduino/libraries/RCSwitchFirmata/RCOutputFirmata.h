/*
  RCOutputFirmata.h - Firmata library

  Version: 2.0.0-SNAPSHOT
  Author:  git-developer ( https://github.com/git-developer )
   
  Description
  -----------
   This library is an adapter between the firmata protocol and the RCSwitch
   library. It allows to send radio messages.

  Usage
  -----
   1.) Connect a RC receiver to a digital pin of your Arduino board
   2.) Add RCSwitchFirmata, ConfigurableFirmata and RCSwitch as arduino libraries
   3.) Include RCOutputFirmata in RCSwitchFirmata
   4.) Upload RCSwitchFirmata and connect Arduino to host
   5.) Send attach message to configure the pin as RC sender

   On success, you may send radio messages from the host. Every message that is
   sent from the host will be echoed back as acknowledgement.
  
  Message format
  --------------
    byte 0:    subcommand
    byte 1:    pin
    bytes 2-n: subcommand specific parameters

  Parameters
  ----------
    SETUP_ATTACH:
     Description:   Configure a pin as RC sender
     Value space:   Arduino pin numbers

    SETUP_DETACH:
     Description:   Remove a pin as RC sender
     Value space:   Arduino pin numbers

    CONFIG_PROTOCOL:
     Description:   Set the RCSwitch parameter "protocol"
     Value space:   Defined by RCSwitch (RCSwitch 2.51: 1-3)
     Default value: Defined by RCSwitch (RCSwitch 2.51: 1)

    CONFIG_PULSE_LENGTH:
     Description:   Set the RCSwitch parameter "pulse length"
     Value space:   Defined by RCSwitch (RCSwitch 2.51: int)
     Default value: Defined by RCSwitch (RCSwitch 2.51: 350)

    CONFIG_REPEAT_TRANSMIT:
     Description:   Set the RCSwitch parameter "repeat transmit"
     Value space:   Defined by RCSwitch (RCSwitch 2.51: int)
     Default value: Defined by RCSwitch (RCSwitch 2.51: 10)

    CODE_TRISTATE:
     Description:   Send a tristate code
     Value space:   char[]

    CODE_LONG:
     Description:   Send a long code
     Value space:   long

    CODE_CHAR:
     Description:   Send a character code
     Value space:   char[]

    CODE_TRISTATE_PACKED:
     Description:   Send a tristate code
     Value space:   byte[] - every byte is composed of 4 tristate bits
                    (defined as TRISTATE_? constants in this file)

  Downloads
  ---------
   RCSwitchFirmata:     https://github.com/git-developer/RCSwitchFirmata
   ConfigurableFirmata: https://github.com/firmata/ConfigurableFirmata
   RCSwitch:            https://github.com/sui77/rc-switch

  License
  -------
   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2.1 of the License, or (at your option) any later version.

   See file LICENSE.txt for further informations on licensing terms.
*/

#ifndef RCOutputFirmata_h
#define RCOutputFirmata_h

#include <FirmataFeature.h>
#include <RCSwitch.h>

#define RCSEND_DATA             0x7C // Sysex command: send RC data

/* Subcommands */
#define UNKNOWN                 0x00

#define SETUP_ATTACH            0x01
#define SETUP_DETACH            0x02

#define CONFIG_PROTOCOL         0x11
#define CONFIG_PULSE_LENGTH     0x12
#define CONFIG_REPEAT_TRANSMIT  0x14

#define CODE_TRISTATE           0x21
#define CODE_LONG               0x22
#define CODE_CHAR               0x24
#define CODE_TRISTATE_PACKED    0x28

/* Tristate bit values */
#define TRISTATE_0              0x00
#define TRISTATE_F              0x01
#define TRISTATE_RESERVED       0x02
#define TRISTATE_1              0x03

class RCOutputFirmata:public FirmataFeature
{

public:
  
  /**
   * When a command was executed successfully,
   * it will be mirrored back to the host.
   * This may be used to track errors.
   */
  boolean handleSysex(byte command, byte argc, byte* argv);
  void reset();

private:

  /** 1 sender per pin */
  RCSwitch* senders[TOTAL_PINS];
  
  /**
   * Initializes a sender for a pin.
   *
   * @param pin Pin to associate to a sender
   */
  void attach(byte pin);
  
  /**
   * Removes the sender from a pin.
   *
   * @param pin Pin that has a sender associated
   */
  void detach(byte pin);

  /**
   * Sends a tristate code via RCSwitch.
   *
   * @param sender RC sender
   * @param data   Tristate bits as char array ('0', 'F' and '1')
   * 
   * @return Number of processed data bytes
   */
  byte sendTristate(RCSwitch *sender, byte *data);

  /**
   * Sends a tristate code via RCSwitch.
   *
   * @param sender RC sender
   * @param data   Tristate bits in packed format
   *                 (byte array with 4 tristate bits per byte)
   * @param length Length of data in bytes
   *
   * @return Number of processed data bytes
   */
  byte sendPackedTristate(RCSwitch *sender, byte *data, byte length);

  /**
   * Sends a code given as long value via RCSwitch.
   *
   * @param sender RC sender
   * @param data data[0..1]: number of bits to send; data[2..5]: bits to send
   *
   * @return Number of processed data bytes
   */
  byte sendLong(RCSwitch *sender, byte *data);

  /**
   * Sends a code given as char array via RCSwitch.
   *
   * @param sender RC sender
   * @param data   characters to send (null-terminated char array)
   *
   * @return Number of processed data bytes
   */
  byte sendString(RCSwitch *sender, byte *data);

  /**
   * Converts a byte[] with packed tristate bits to a string.
   *
   * @param tristateBytes byte[] with 4 tristate bits per byte
   * @param length        Length of the byte[]
   * @param tristateCode  Target for the string
   *
   * @return Number of written characters
   */
  byte unpack(byte *tristateBytes, byte length, char* tristateCode);
  
  /**
   * Converts a string with tristate bits to a byte[] with packed tristate bits.
   *
   * @param tristateCode  String with tristate bits ('0', '1', 'F')
   * @param length        Length of the string
   * @param tristateBytes Target for the tristate bits
   *                        with 4 tristate bits per byte
   *
   * @return Number of written bytes
   */
  byte pack(char* tristateCode, byte length, byte *tristateBytes);

  /**
   * Extracts a tristate bit from a byte.
   *
   * @param tristateByte  A byte containing 4 tristate bits
   * @param index         Index of the tristate bit to read (0..3)
   *
   * @return Char representation of the requested tristate bit
   */
  char getTristateChar(byte tristateByte, byte index);

  /**
   * Sets a tristate bit within a byte.
   *
   * @param tristateByte  A byte of 4 tristate bits
   * @param index         Index of the tristate bit to write (0..3)
   * @param char          Tristate bit to write
   *
   * @return The given byte with the requested tristate bit set
   */
  byte setTristateBit(byte tristateByte, byte index, char tristateChar);

  /**
   * Send a message to the firmata host.
   *
   * @param subcommand Details about the message
   *                     (see the constants defined above)
   * @param pin        Pin that corresponds to the message
   * @param length     Message length
   * @param data       Message content
   */  
  void sendMessage(byte subcommand, byte pin, byte length, byte *data);

};

#endif
