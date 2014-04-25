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

#include <utility/FirmataFeature.h>
#include <RCSwitch.h>

#define RCSWITCH_SEND 0x67  // sysex command to send a RCSwitch message
#define RCSWITCH_PIN  0x0A  // used for capability query

/* subcommands for RCSWITCH_SEND */
#define RCSWITCH_SEND_MESSAGE          0x10
#define RCSWITCH_SET_PULSE_LENGTH      0x11
#define RCSWITCH_SET_REPEAT_TRANSMIT   0x12
#define RCSWITCH_SET_RECEIVE_TOLERANCE 0x13
#define RCSWITCH_SET_PROTOCOL          0x14

#define TRISTATE_0 0x00
#define TRISTATE_F 0x01
#define TRISTATE_1 0x03

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

  void sendMessage(byte pin, byte length, byte* tristateBytes);

  void setPulseLength(byte pin, int pulseLength);
  void setRepeatTransmit(byte pin, int count);
  void setReceiveTolerance(byte pin, int percent);
  void setProtocol(byte pin, int protocol);

  int asInt(byte* data);
  void send(String name, int value);
};

#endif
