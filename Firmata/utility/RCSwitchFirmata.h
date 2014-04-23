/*
  RCSwitchFirmata.h - Firmata library

  Version: DEVELOPMENT SNAPSHOT
  Date:    2014-04-23
  Author:  fhem-user ( http://forum.fhem.de/index.php?action=emailuser;sa=email;uid=1713 )
   
  This library is free software; you can redistribute it and/or
  modify it under the terms of the GNU Lesser General Public
  License as published by the Free Software Foundation; either
  version 2.1 of the License, or (at your option) any later version.

  See file LICENSE.txt for further informations on licensing terms.
*/

#ifndef RCSwitchFirmata_h
#define RCSwitchFirmata_h

#include "../RCSwitch/RCSwitch.h"
#include <Firmata.h>
#include <utility/FirmataFeature.h>

#define RCSWITCH_SEND 0x67 // used as sysex command to send a RCSwitch message
#define RCSWITCH_PIN 0x0A          // used for capability query

#define TRISTATE_0 0x00
#define TRISTATE_F 0x01
#define TRISTATE_1 0x02

class RCSwitchFirmata:public FirmataFeature
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

};

#endif
