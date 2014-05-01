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
    Firmata.write(1); // data within this feature doesn't have a fixed resolution
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
  if (command != SYSEX_COMMAND_RC_DATA || argc <= 2) { // required: pin, subcommand, value
    return false;
  }
  byte pin = argv[0];
  if (Firmata.getPinMode(pin)==IGNORE) {
    return false;
  }
  RCSwitch *sender = senders[pin];
  if (!sender) {
    return false;
  }
  
  /* 
   * argc gives the number of 7-bit bytes,
   * length gives the number of 8-bit data bytes
   */
  byte length = ((argc-2) * 7) >> 3;
  if (length == 0) {
    return false;
  }
  
  byte subcommand = argv[1];
  byte *data = (byte*) argv+2;
  Encoder7Bit.readBinary(length, data, data);
  int value = *(int*) data;

  /*
   * This if-else statement should not be changed to a switch
   * because the board doesn't respond anymore after the first
   * run of this method.
   */
  if (subcommand == SEND_CODE) { 
    char tristateCode[length];
    convert(data, length, tristateCode);
    sender->sendTriState(tristateCode);
    convert(tristateCode, length, data);
  } else {
    int value = *(int*) data;
    if (subcommand == SET_PROTOCOL) {
      sender->setProtocol(value);
    } else if (subcommand == SET_PULSE_LENGTH) {
      sender->setPulseLength(value);
    } else if (subcommand == SET_REPEAT_TRANSMIT) {
      sender->setRepeatTransmit(value);
    } else {
      subcommand = UNKNOWN;
    }
  }
  
  sendReply(pin, subcommand, length, data);
  return true;
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

void RCOutputFirmata::convert(byte *tristateBytes, byte length, char* tristateCode)
{
  for (int i = 0; i < length; i++) {
    switch (tristateBytes[i]) {
      case TRISTATE_0: tristateCode[i] = '0'; break;
      case TRISTATE_F: tristateCode[i] = 'F'; break;
      case TRISTATE_1: tristateCode[i] = '1'; break;
      default:         tristateCode[i] = 'X';
    }
  }
}

void RCOutputFirmata::convert(char* tristateCode, byte length, byte *tristateBytes)
{
  for (int i = 0; i < length; i++) {
    switch (tristateCode[i]) {
      case '0': tristateBytes[i] = TRISTATE_0; break;
      case 'F': tristateBytes[i] = TRISTATE_F; break;
      case '1': tristateBytes[i] = TRISTATE_1; break;
      default:  tristateBytes[i] = TRISTATE_RESERVED;
    }
  }
}

void RCOutputFirmata::sendReply(byte pin, byte subcommand, byte length, byte *data)
{
  Firmata.write(START_SYSEX);
  Firmata.write(SYSEX_COMMAND_RC_DATA);
  Firmata.write(pin);
  Firmata.write(subcommand);
  Encoder7Bit.startBinaryWrite();
  for (int i = 0; i < length; i++) {
    Encoder7Bit.writeBinary(data[i]);
  }
  Encoder7Bit.endBinaryWrite();
  Firmata.write(END_SYSEX);
}

void RCOutputFirmata::debugLog(String name, int value) {
  String s = name;
  s += "=";
  s = s + value;
  s += ".";
  int size = s.length()+1;
  char chars[size];
  s.toCharArray(chars, size);
  Firmata.sendString(chars);
}
