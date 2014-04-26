/*
  RCOutputFirmata.cpp - Firmata library

  Version: DEVELOPMENT SNAPSHOT
  Date:    2014-04-26
  Author:  fhem-user ( http://forum.fhem.de/index.php?action=emailuser;sa=email;uid=1713 )

  This library is free software; you can redistribute it and/or
  modify it under the terms of the GNU Lesser General Public
  License as published by the Free Software Foundation; either
  version 2.1 of the License, or (at your option) any later version.

  See file LICENSE.txt for further informations on licensing terms.
*/

#include "RCOutputFirmata.h"
#include <Encoder7Bit.h>

void RCOutputFirmata::handleCapability(byte pin)
{
  if (IS_PIN_DIGITAL(pin)) {
    Firmata.write(PINMODE_RC_TRANSMIT);
    Firmata.write(84); //(5 group symbols + 5 device symbols + 2 switch symbols) * 7 bit per tristate symbol
}
}

boolean RCOutputFirmata::handlePinMode(byte pin, int mode)
{
  if (IS_PIN_DIGITAL(pin)) {
    if (mode == PINMODE_RC_TRANSMIT) {
      attach(pin);
      return true;
    } else {
      detach(pin);
    }
  }
  return false;
}

void RCOutputFirmata::reset()
{
  for (byte pin = 0; pin < TOTAL_PINS; pin++) {
    if (IS_PIN_DIGITAL(pin)) {
      detach(pin);
    }
  }
}

boolean RCOutputFirmata::handleSysex(byte command, byte argc, byte *argv)
{
  if (command == SYSEX_COMMAND_RC_DATA && argc > 1) { // at least pin & subcommand are necessary
    byte pin = argv[0];
    if (Firmata.getPinMode(pin)==IGNORE) {
      return false;
    }
    RCSwitch *sender = senders[pin];
    if (sender) {
    }
    byte subcommand = argv[1];
    byte length = argc-2;
    byte *data = (byte*) argv+2;
RCOutputFirmata::debugLog("subcommand", subcommand);
RCOutputFirmata::debugLog("data[0]", data[0]);
RCOutputFirmata::debugLog("data[1]", data[1]);

    switch (subcommand) {
      case SEND_CODE:
        char tristateCode[length];
        convertToTristate(data, length, tristateCode);
        sender->sendTriState(tristateCode);
        break;
      case SET_PROTOCOL:
        sender->setProtocol(unpack(data)); break;
      case SET_PULSE_LENGTH:
        sender->setPulseLength(unpack(data)); break;
      case SET_REPEAT_TRANSMIT:
        sender->setRepeatTransmit(unpack(data)); break;
        
      default:
        debugLog("Unknown subcommand", subcommand); break;
    }
    
    return true;
  }
  return false;
}

void RCOutputFirmata::attach(byte pin)
{
  RCSwitch *sender = senders[pin];
  if (!sender) {
    sender = new RCSwitch();
    senders[pin] = sender;
  }
  sender->enableTransmit(pin); 
}

void RCOutputFirmata::detach(byte pin)
{
  RCSwitch *sender = senders[pin];
  if (sender) {
    sender->disableTransmit();
    free(sender);
    senders[pin]=NULL;
  }
}

void RCOutputFirmata::convertToTristate(byte *tristateBytes, byte length, char* tristateCode) {
  for (int i = 0; i < length; i++) {
    switch (tristateBytes[i]) {
      case TRISTATE_0: tristateCode[i] = '0'; break;
      case TRISTATE_F: tristateCode[i] = 'F'; break;
      case TRISTATE_1: tristateCode[i] = '1'; break;
      default: break;
    }
  }
}

/*
 * In:  2 x 7-Bit
 * Out: int
 */
int RCOutputFirmata::unpack(byte* data) {
 byte intBytes[2];
 Encoder7Bit.readBinary(2, data, intBytes);
RCOutputFirmata::debugLog("intBytes[0]", intBytes[0]);
RCOutputFirmata::debugLog("intBytes[1]", intBytes[1]);
 int i = *(int*) intBytes;
 return i;
}

void RCOutputFirmata::debugLog(String name, int value) {
 String s = name;
 s += "=";
 s = s + value;
 char chars[s.length()+1];
 s.toCharArray(chars, s.length()+1);
 Firmata.sendString(chars);
}