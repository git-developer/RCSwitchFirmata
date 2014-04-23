/*
  RCSwitchFirmata.cpp - Firmata library

  Version: DEVELOPMENT SNAPSHOT
  Date:    2014-04-23
  Author:  fhem-user ( http://forum.fhem.de/index.php?action=emailuser;sa=email;uid=1713 )

  This library is free software; you can redistribute it and/or
  modify it under the terms of the GNU Lesser General Public
  License as published by the Free Software Foundation; either
  version 2.1 of the License, or (at your option) any later version.

  See file LICENSE.txt for further informations on licensing terms.
*/

#include "RCSwitchFirmata.h"

void RCSwitchFirmata::handleCapability(byte pin)
{
  if (IS_PIN_DIGITAL(pin)) {
    Firmata.write(RCSWITCH_PIN);
    Firmata.write(84); //(5 group symbols + 5 device symbols + 2 switch symbols) * 7 bit per tristate symbol
  }
}

boolean RCSwitchFirmata::handlePinMode(byte pin, int mode)
{
  if (IS_PIN_DIGITAL(pin)) {
    if (mode == RCSWITCH_PIN) {
      attach(pin);
      return true;
    } else {
      detach(pin);
    }
  }
  return false;
}

void RCSwitchFirmata::reset()
{
  for (byte pin=0; pin<TOTAL_PINS; pin++) {
    if (IS_PIN_DIGITAL(pin)) {
      detach(pin);
    }
  }
}

boolean RCSwitchFirmata::handleSysex(byte command, byte argc, byte* argv)
{
  if (command == RCSWITCH_SEND) {
    byte pin = argv[0];
    if (Firmata.getPinMode(pin)==IGNORE) {
      return false;
    }
    
    char tristateCode[argc-1];
    for (int i = 1; i < argc; i++) {
      switch(argv[i]) {
        case TRISTATE_0: tristateCode[i-1] = '0'; break;
        case TRISTATE_F: tristateCode[i-1] = 'F'; break;
        case TRISTATE_1: tristateCode[i-1] = '1'; break;
        default: break;
      }
    }
    senders[pin]->sendTriState(tristateCode);
    return true;
  }
  return false;
}

void RCSwitchFirmata::attach(byte pin)
{
  RCSwitch* sender = senders[pin];
  if (!sender) {
    sender = new RCSwitch();
    senders[pin] = sender;
  }
  sender->enableTransmit(pin); 
}

void RCSwitchFirmata::detach(byte pin)
{
  RCSwitch* sender = senders[pin];
  if (sender) {
    free(sender);
    senders[pin]=NULL;
  }
}
