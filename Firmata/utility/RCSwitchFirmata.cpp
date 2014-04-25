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
#include <Encoder7Bit.h>

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
  for (byte pin = 0; pin < TOTAL_PINS; pin++) {
    if (IS_PIN_DIGITAL(pin)) {
      detach(pin);
    }
  }
}

boolean RCSwitchFirmata::handleSysex(byte command, byte argc, byte *argv)
{
  if (command == RCSWITCH_SEND && argc > 1) { // at least pin & subcommand are necessary
    byte pin = argv[0];
    if (Firmata.getPinMode(pin)==IGNORE) {
      return false;
    }
    
    byte subcommand = argv[1];
    byte length = argc-2;
    byte *data = (byte*) argv+2;
RCSwitchFirmata::send("subcommand", subcommand);
RCSwitchFirmata::send("data[0]", data[0]);
RCSwitchFirmata::send("data[1]", data[1]);
    switch (subcommand) {
      case RCSWITCH_SEND_MESSAGE:          sendMessage(pin, length, data); break;
      case RCSWITCH_SET_PULSE_LENGTH:      setPulseLength(pin, asInt(data)); break;
      case RCSWITCH_SET_REPEAT_TRANSMIT:   setRepeatTransmit(pin, asInt(data)); break;
      case RCSWITCH_SET_RECEIVE_TOLERANCE: setReceiveTolerance(pin, asInt(data)); break;
      case RCSWITCH_SET_PROTOCOL:          setProtocol(pin, asInt(data)); break;
      default: send("Unknown subcommand", subcommand); break;
    }
    
    return true;
  }
  return false;
}

void RCSwitchFirmata::attach(byte pin)
{
  RCSwitch *sender = senders[pin];
  if (!sender) {
    sender = new RCSwitch();
    senders[pin] = sender;
  }
  sender->enableTransmit(pin); 
}

void RCSwitchFirmata::detach(byte pin)
{
  RCSwitch *sender = senders[pin];
  if (sender) {
    sender->disableTransmit();
    free(sender);
    senders[pin]=NULL;
  }
}

void RCSwitchFirmata::sendMessage(byte pin, byte length, byte *tristateBytes)
{
    RCSwitch *sender = senders[pin];
    if (sender) {
      char tristateCode[length];
      for (int i = 0; i < length; i++) {
        switch (tristateBytes[i]) {
          case TRISTATE_0: tristateCode[i] = '0'; break;
          case TRISTATE_F: tristateCode[i] = 'F'; break;
          case TRISTATE_1: tristateCode[i] = '1'; break;
          default: break;
        }
      }
      sender->sendTriState(tristateCode);
    }
}

void RCSwitchFirmata::setPulseLength(byte pin, int pulseLength)
{
send("pulseLength", pulseLength);
    RCSwitch *sender = senders[pin];
    if (sender) {
      sender->setPulseLength(pulseLength);
    }
}
void RCSwitchFirmata::setRepeatTransmit(byte pin, int count)
{
    RCSwitch *sender = senders[pin];
    if (sender) {
      sender->setRepeatTransmit(count);
    }
}
void RCSwitchFirmata::setReceiveTolerance(byte pin, int percent)
{
    RCSwitch *sender = senders[pin];
    if (sender) {
      sender->setReceiveTolerance(percent);
    }
}
void RCSwitchFirmata::setProtocol(byte pin, int protocol)
{
    RCSwitch *sender = senders[pin];
    if (sender) {
      sender->setProtocol(protocol);
    }
}

int RCSwitchFirmata::asInt(byte* data) {
 byte intBytes[2];
 Encoder7Bit.readBinary(2, data, intBytes);
RCSwitchFirmata::send("intBytes[0]", intBytes[0]);
RCSwitchFirmata::send("intBytes[1]", intBytes[1]);
 int i = *(int*) intBytes;
 return i;
}

void RCSwitchFirmata::send(String name, int value) {
 String s = name;
 s += "=";
 s = s + value;
 char chars[s.length()+1];
 s.toCharArray(chars, s.length()+1);
 Firmata.sendString(chars);
}