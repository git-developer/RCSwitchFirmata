/*
  RCOutputFirmata.cpp - Firmata library

  See file 'README.md' for documentation.
*/

#include "RCOutputFirmata.h"
#include <Encoder7Bit.h>

void RCOutputFirmata::handleCapability(byte pin)
{
}

boolean RCOutputFirmata::handlePinMode(byte pin, int mode) {
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
  /* required: subcommand, pin */
  if (command != RCOUTPUT_DATA || argc < 2) {
    return false;
  }
  byte subcommand = argv[0];
  byte pin = argv[1];
  if (Firmata.getPinMode(pin) == PIN_MODE_IGNORE) {
    return false;
  }

  /* handling of setup messages (without value) */
  if ((subcommand == RCOUTPUT_ATTACH) || (subcommand == RCOUTPUT_DETACH)) {
    if (subcommand == RCOUTPUT_ATTACH) {
      attach(pin);
    }
    if (subcommand == RCOUTPUT_DETACH) {
      detach(pin);
    }
    sendMessage(subcommand, pin);
    return true;
  }

  /* required: subcommand, pin, value */
  if (argc < 3) {
    return false;
  }
  RCSwitch *sender = senders[pin];
  if (!sender) { // pin was not attached yet
    return false;
  }
  
  /* 
   * argc gives the number of 7-bit bytes (control and data),
   * length is the number of 8-bit bytes (data only)
   */
  byte length = ((argc-2) * 7) >> 3;
  if (length == 0) {
    return false;
  }
  
  byte *data = (byte*) argv+2;
  Encoder7Bit.readBinary(length, data, data); // decode in-place
  int value = *(int*) data;

  switch (subcommand) {
    case RCOUTPUT_PROTOCOL:             { sender->setProtocol(value); break; }
    case RCOUTPUT_PULSE_LENGTH:         { sender->setPulseLength(value); break; }
    case RCOUTPUT_REPEAT_TRANSMIT:      { sender->setRepeatTransmit(value); break; }
    case RCOUTPUT_CODE_TRISTATE:        { length = sendTristate(sender, data); break; }
    case RCOUTPUT_CODE_LONG:            { length = sendLong(sender, data); break; }
    case RCOUTPUT_CODE_CHAR:            { length = sendString(sender, data); break; }
    case RCOUTPUT_CODE_TRISTATE_PACKED: { length = sendPackedTristate(sender, data, length); break; }
    default:                            { subcommand = RCOUTPUT_UNKNOWN; }
  }
  sendMessage(subcommand, pin, length, data);
  return subcommand != RCOUTPUT_UNKNOWN;
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
    senders[pin] = NULL;
  }
}

byte RCOutputFirmata::sendTristate(RCSwitch *sender, byte *data)
{
  char* code = (char*) data;
  sender->sendTriState(code);
  return strlen(code);
}

byte RCOutputFirmata::sendPackedTristate(RCSwitch *sender, byte *data, byte length)
{
  char tristateCode[length*4]; // 4 tristate bits per byte
  byte charCount = unpack(data, length, tristateCode);
  sender->sendTriState(tristateCode);
  return pack(tristateCode, charCount, data);
}

byte RCOutputFirmata::sendLong(RCSwitch *sender, byte *data)
{
  unsigned int bitCount = *(unsigned int*) data;
  unsigned long code    = *(unsigned long*) (data+2);
  sender->send(code, bitCount);
  return 6; // 2 bytes bitCount + 4 bytes code
}

byte RCOutputFirmata::sendString(RCSwitch *sender, byte *data)
{
  char* code = (char*) data;
  sender->send(code);
  return strlen(code);
}

byte RCOutputFirmata::unpack(byte *tristateBytes, byte length, char* tristateCode)
{
  byte charCount = 0;
  for (byte i = 0; i < length; i++) {
    for (byte j = 0; j < 4; j++) {
      tristateCode[charCount++] = getTristateChar(tristateBytes[i], j);
    }
  }
  return charCount;
}

byte RCOutputFirmata::pack(char* tristateCode, byte length, byte *tristateBytes)
{
  byte count = 0;
  for (; count < length; count++) {
    tristateBytes[count/4] = setTristateBit(tristateBytes[count/4],
                                            count & 0x03,
                                            tristateCode[count]);
  }
  
  /* fill last byte if necessary */
  for (; (count & 0x03) != 0; count++) {
    tristateBytes[count/4] = setTristateBit(tristateBytes[count/4],
                                            count & 0x03,
                                            RCOUTPUT_TRISTATE_RESERVED);
  }
  return count/4;
}

char RCOutputFirmata::getTristateChar(byte tristateByte, byte index)
{

  /* 
   * An invalid character is used as default
   * so that no valid value will be used on error
   */
  char c = 'X'; // 
  byte shift = 2*(index & 0x03); // 0, 2, 4 or 6
  byte tristateBit = ((tristateByte << shift) >> 6) & 0x3;
  switch (tristateBit) {
    case RCOUTPUT_TRISTATE_0: c = '0'; break;
    case RCOUTPUT_TRISTATE_F: c = 'F'; break;
    case RCOUTPUT_TRISTATE_1: c = '1'; break;
  }
  return c;
}

byte RCOutputFirmata::setTristateBit(byte tristateByte, byte index, char tristateChar)
{
  byte shift = 6-(2*index); // 6, 4, 2 or 0
  byte clear = ~(0x03 << shift); // bitmask to clear the requested 2 bits
  byte tristateBit = RCOUTPUT_TRISTATE_RESERVED;
  switch (tristateChar) {
    case '0': tristateBit = RCOUTPUT_TRISTATE_0; break;
    case 'F': tristateBit = RCOUTPUT_TRISTATE_F; break;
    case '1': tristateBit = RCOUTPUT_TRISTATE_1; break;
  }
  
  /* remove old data from the requested position and set the tristate bit */
  return (tristateByte & clear) | (tristateBit << shift);
}

void RCOutputFirmata::sendMessage(byte subcommand, byte pin)
{
  Firmata.write(START_SYSEX);
  Firmata.write(RCOUTPUT_DATA);
  Firmata.write(subcommand);
  Firmata.write(pin);
  Firmata.write(END_SYSEX);
}

void RCOutputFirmata::sendMessage(byte subcommand, byte pin, byte length, byte *data)
{
  Firmata.write(START_SYSEX);
  Firmata.write(RCOUTPUT_DATA);
  Firmata.write(subcommand);
  Firmata.write(pin);
  Encoder7Bit.startBinaryWrite();
  for (int i = 0; i < length; i++) {
    Encoder7Bit.writeBinary(data[i]);
  }
  Encoder7Bit.endBinaryWrite();
  Firmata.write(END_SYSEX);
}
