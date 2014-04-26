/*
  RCOutputFirmata.h - Firmata library

  Version: DEVELOPMENT SNAPSHOT
  Date:    2014-04-26
  Author:  fhem-user ( http://forum.fhem.de/index.php?action=emailuser;sa=email;uid=1713 )
   
  This library is free software; you can redistribute it and/or
  modify it under the terms of the GNU Lesser General Public
  License as published by the Free Software Foundation; either
  version 2.1 of the License, or (at your option) any later version.

  See file LICENSE.txt for further informations on licensing terms.
*/

#ifndef RCOutputFirmata_h
#define RCOutputFirmata_h

#include <utility/FirmataFeature.h>
#include <RCSwitch.h>

#define SYSEX_COMMAND_RC_DATA 0x67  // sysex command to for RC data
#define PINMODE_RC_TRANSMIT   0x0A  // pin mode, used for capability query

/* subcommands */
#define SEND_CODE             0x10
#define SET_PROTOCOL          0x11
#define SET_PULSE_LENGTH      0x12
#define SET_REPEAT_TRANSMIT   0x13

#define TRISTATE_0 0x00
#define TRISTATE_F 0x01
#define TRISTATE_1 0x03

class RCOutputFirmata:public FirmataFeature
{

public:
  boolean handlePinMode(byte pin, int mode);
  void handleCapability(byte pin);
  boolean handleSysex(byte command, byte argc, byte* argv);
  void reset();

private:
  RCSwitch* senders[TOTAL_PINS];
  void attach(byte pin);
  void detach(byte pin);

  void convertToTristate(byte *tristateBytes, byte length, char* tristateCode);
  int unpack(byte* data);
  void debugLog(String name, int value);
};

#endif
