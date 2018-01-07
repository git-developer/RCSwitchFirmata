/*
  RCInputFirmata.h - Firmata library

  See file 'README.md' for documentation.
*/

#ifndef RCInputFirmata_h
#define RCInputFirmata_h

#include <FirmataFeature.h>
#include <RCSwitch.h>

/* Sysex command: receive RC data */
#define RCINPUT_DATA            0x5D

/* Subcommands */
#define RCINPUT_UNKNOWN         0x00
#define RCINPUT_ATTACH          0x01
#define RCINPUT_DETACH          0x02
#define RCINPUT_TOLERANCE       0x31
#define RCINPUT_ENABLE_RAW_DATA 0x32
#define RCINPUT_MESSAGE         0x41

#define RCINPUT_NO_INTERRUPT -1

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
   *         or RCINPUT_NO_INTERRUPT if the pin cannot be used for external interrupts
   */
  byte getInterrupt(byte pin);

};

#endif
