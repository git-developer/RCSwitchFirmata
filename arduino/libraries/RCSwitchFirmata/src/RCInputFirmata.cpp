/*
  RCInputFirmata.cpp - Firmata library

  See file 'README.md' for documentation.
*/

#include "RCInputFirmata.h"
#include <Encoder7Bit.h>

void RCInputFirmata::handleCapability(byte pin)
{
}

boolean RCInputFirmata::handlePinMode(byte pin, int mode) {
  return false;
}

void RCInputFirmata::reset()
{
  for (byte pin = 0; pin < TOTAL_PINS; pin++) {
    if (IS_PIN_INTERRUPT(pin)) {
      detach(pin);
    }
  }
  rawdataEnabled = false;
}

boolean RCInputFirmata::handleSysex(byte command, byte argc, byte *argv)
{
  /* required: subcommand, pin */
  if (command != RCINPUT_DATA || argc < 2) {
    return false;
  }
  byte subcommand = argv[0];
  byte pin = argv[1];
  if (Firmata.getPinMode(pin) == PIN_MODE_IGNORE) {
    return false;
  }

  /* handling of setup messages (without value) */
  if ((subcommand == RCINPUT_ATTACH) || (subcommand == RCINPUT_DETACH)) {
    boolean success = true;
    if (subcommand == RCINPUT_ATTACH) {
      success = attach(pin);
    }
    if (subcommand == RCINPUT_DETACH) {
      detach(pin);
    }
    sendMessage(subcommand, pin);
    return success;
  }

  /* required: subcommand, pin, value */
  if (argc < 3) {
    return false;
  }
  RCSwitch *receiver = receivers[pin];
  if (!receiver) { // pin was not attached yet
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
   case RCINPUT_TOLERANCE:       { receiver->setReceiveTolerance(value); break; }
   case RCINPUT_ENABLE_RAW_DATA: { rawdataEnabled = (boolean) data[0]; break; }
   default:                      { subcommand = RCINPUT_UNKNOWN; }
  }
  sendMessage(subcommand, pin, length, data, 0, data);
  return subcommand != RCINPUT_UNKNOWN;
}

void RCInputFirmata::report()
{
  for (byte pin = 0; pin < TOTAL_PINS; pin++) {
    if (IS_PIN_INTERRUPT(pin)) {
      RCSwitch *receiver = receivers[pin];
      if (receiver && receiver->available()) {
        unsigned long value    = receiver->getReceivedValue();
        unsigned int bitCount  = receiver->getReceivedBitlength();
        unsigned int delay     = receiver->getReceivedDelay();
        unsigned int protocol  = receiver->getReceivedProtocol();
        
        /* 
         * Note: The rawdata values can be changed while we read them.
         * This cannot be avoided because rawdata is written from an interrupt
         * routine.
         */
        unsigned int *rawdata  = receiver->getReceivedRawdata();
        receiver->resetAvailable();

        byte data[10];
        data[0] = (value >> 24) & 0xFF;
        data[1] = (value >> 16) & 0xFF;
        data[2] = (value >>  8) & 0xFF;
        data[3] = value & 0xFF;
        
        data[4] = (bitCount >> 8) & 0xFF;
        data[5] = bitCount & 0xFF;
        
        data[6] = (delay >> 8) & 0xFF;
        data[7] = delay & 0xFF;
        
        data[8] = (protocol >> 8) & 0xFF;
        data[9] = protocol & 0xFF;
        
        byte rawdataLength = rawdataEnabled ? 2*RCSWITCH_MAX_CHANGES : 0;
        
        sendMessage(RCINPUT_MESSAGE, pin, 10, data, rawdataLength, (byte*) rawdata);
      }
    }
  }
}

boolean RCInputFirmata::attach(byte pin)
{
  int interrupt = getInterrupt(pin);
  if (interrupt == RCINPUT_NO_INTERRUPT) {
    return false;
  }
  pinMode(PIN_TO_DIGITAL(pin), INPUT);
  RCSwitch *receiver = receivers[pin];
  if (!receiver) {
    receiver = new RCSwitch();
    receivers[pin] = receiver;
  }
  receiver->enableReceive(interrupt);
  return true;
}

void RCInputFirmata::detach(byte pin)
{
  RCSwitch *receiver = receivers[pin];
  if (receiver) {
    receiver->disableReceive();
    free(receiver);
    receivers[pin]=NULL;
  }
}


void RCInputFirmata::sendMessage(byte subcommand, byte pin)
{
  Firmata.write(START_SYSEX);
  Firmata.write(RCINPUT_DATA);
  Firmata.write(subcommand);
  Firmata.write(pin);
  Firmata.write(END_SYSEX);
}

void RCInputFirmata::sendMessage(byte subcommand, byte pin,
                                 byte length1, byte *data1,
                                 byte length2, byte *data2)
{
  Firmata.write(START_SYSEX);
  Firmata.write(RCINPUT_DATA);
  Firmata.write(subcommand);
  Firmata.write(pin);
  Encoder7Bit.startBinaryWrite();
  for (int i = 0; i < length1; i++) {
    Encoder7Bit.writeBinary(data1[i]);
  }
  for (int i = 0; i < length2; i++) {
    Encoder7Bit.writeBinary(data2[i]);
  }
  Encoder7Bit.endBinaryWrite();
  Firmata.write(END_SYSEX);
}

byte RCInputFirmata::getInterrupt(byte pin) {
// this method fits common Arduino board including Mega.
// TODO check how this can be made more flexible to fit different boards

  byte interrupt = RCINPUT_NO_INTERRUPT;
  switch (pin) {
    case   2: interrupt = 0; break;
    case   3: interrupt = 1; break;
    case  21: interrupt = 2; break;
    case  20: interrupt = 3; break;
    case  19: interrupt = 4; break;
    case  18: interrupt = 5; break;
  }
  return interrupt;
}
