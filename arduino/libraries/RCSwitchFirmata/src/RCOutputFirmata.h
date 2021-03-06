/*
  RCOutputFirmata.h - Firmata library

  See file 'README.md' for documentation.
*/

#ifndef RCOutputFirmata_h
#define RCOutputFirmata_h

#include <FirmataFeature.h>
#include <RCSwitch.h>

/* Sysex command: send RC data */
#define RCOUTPUT_DATA                 0x5C

/* Subcommands */
#define RCOUTPUT_UNKNOWN              0x00
#define RCOUTPUT_ATTACH               0x01
#define RCOUTPUT_DETACH               0x02
#define RCOUTPUT_PROTOCOL             0x11
#define RCOUTPUT_PULSE_LENGTH         0x12
#define RCOUTPUT_REPEAT_TRANSMIT      0x14
#define RCOUTPUT_CODE_TRISTATE        0x21
#define RCOUTPUT_CODE_LONG            0x22
#define RCOUTPUT_CODE_CHAR            0x24
#define RCOUTPUT_CODE_TRISTATE_PACKED 0x28

/* Tristate bit values */
#define RCOUTPUT_TRISTATE_0           0x00
#define RCOUTPUT_TRISTATE_F           0x01
#define RCOUTPUT_TRISTATE_RESERVED    0x02
#define RCOUTPUT_TRISTATE_1           0x03

class RCOutputFirmata:public FirmataFeature
{

public:
  boolean handlePinMode(byte pin, int mode);
  void handleCapability(byte pin);
  
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
   */
  void sendMessage(byte subcommand, byte pin);

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
