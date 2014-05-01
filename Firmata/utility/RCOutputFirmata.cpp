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
debugLog("pinMode", mode);
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
debugLog("handleSysex", command);
  if (command == SYSEX_COMMAND_RC_DATA && argc > 1) { // at least pin & subcommand are necessary
    byte pin = argv[0];
    if (Firmata.getPinMode(pin)==IGNORE) {
      return false;
    }
    RCSwitch *sender = senders[pin];
    if (sender) {
      byte subcommand = argv[1];
      byte length = argc-2;
      byte *data7bit = (byte*) argv+2;

      byte data[12];
      byte* pData = &data[0];

debugLog("length", length);
debugLog("subcommand", subcommand);

      if (subcommand == SEND_CODE) { //change this to a switch statement will lead to unpredictable results (endless loop, no reaction, ...)
        length = 12;
        char tristateCode[length];

        byte data8bit[length];
        Encoder7Bit.readBinary(length, data7bit, data8bit);
        convertToTristate(data8bit, length, tristateCode);
debugLog(tristateCode, 0);
        sender->sendTriState(tristateCode);
        convertFromTristate(tristateCode, length, data);
      } else {
        int value = unpack(data7bit);
debugLog("unpacked value", value);
        if (subcommand == SET_PROTOCOL) {
          sender->setProtocol(value);
        } else if (subcommand == SET_PULSE_LENGTH) {
          sender->setPulseLength(value);
        } else if (subcommand == SET_REPEAT_TRANSMIT) {
          sender->setRepeatTransmit(value);
        } else {
          subcommand = UNKNOWN;
          debugLog("Unknown subcommand", subcommand);
        }
        data[0] = value & 0xFF;
        data[1] = (value >> 8) & 0xFF;
        length = (value >> 14)>0 ? 3:2;
      }
for (int i = 0; i < length; i++) {
  debugLog("data[i]", data[i]);
}
    sendReply(pin, subcommand, length, data);
    return true;
    }
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
      default:         tristateCode[i] = 'X';
    }
  }
}

void RCOutputFirmata::convertFromTristate(char* tristateCode, byte length, byte *tristateBytes) {
debugLog("sizeof(tristateCode)", sizeof(tristateCode));
  for (int i = 0; i < length; i++) {
    switch (tristateCode[i]) {
      case '0': tristateBytes[i] = TRISTATE_0; break;
      case 'F': tristateBytes[i] = TRISTATE_F; break;
      case '1': tristateBytes[i] = TRISTATE_1; break;
      default:  tristateBytes[i] = TRISTATE_RESERVED;
    }
debugLog("tristateBytes[i]", tristateBytes[i]);
  }
}

/*
 * In:  2 x 7-Bit
 * Out: int
 */
int RCOutputFirmata::unpack(byte* data) {
 byte intBytes[2];
 Encoder7Bit.readBinary(2, data, intBytes);
debugLog("intBytes[0]", intBytes[0]);
debugLog("intBytes[1]", intBytes[1]);
 int i = *(int*) intBytes;
 return i;
}

void RCOutputFirmata::sendReply(byte pin, byte subcommand, byte length, byte *data) {
debugLog("sendReply", subcommand);
debugLog("data[0]", data[0]);
debugLog("data[1]", data[1]);
    Firmata.write(START_SYSEX);
    Firmata.write(SYSEX_COMMAND_RC_DATA);
    Firmata.write(pin);
    Firmata.write(subcommand);
    Encoder7Bit.startBinaryWrite();
    for (int i=0; i<length; i++) {
      Encoder7Bit.writeBinary(data[i]);
    }
    Encoder7Bit.endBinaryWrite();
    Firmata.write(END_SYSEX);
}

void RCOutputFirmata::debugLog(String name, int value) {
/* 
  Firmata.sendString(name);
  char chars[6] = "     ";  //reserve the string space first
  itoa(value, chars, 10);
*/ 
 String s = name;
 s += "=";
 s = s + value;
 s += ".";
 int size = s.length()+1;
// size = 30; // without this, I encountered an endless loop :-?
 char chars[size];
 s.toCharArray(chars, size);
 Firmata.sendString(chars);
 
}
