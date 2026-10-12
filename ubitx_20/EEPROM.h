/*************************************************************************
  EEPROM.h -- a small stand-in for the Arduino EEPROM library (QRSS fork).

  The library's get() and put() are templates that the compiler expands
  inline, byte by byte, at every call; CEC makes about 60 such calls.
  These versions call avr-libc's eeprom_*_block functions once instead.
  put() uses eeprom_update_block, so like the library it only writes the
  bytes that change. Only the calls CEC uses are provided.
**************************************************************************/
#ifndef _UBITX_EEPROM_LITE_H__
#define _UBITX_EEPROM_LITE_H__

#include <avr/eeprom.h>
#include <stdint.h>

struct EEPROMLite {
  uint8_t read(int idx) { return eeprom_read_byte((const uint8_t *)idx); }
  void write(int idx, uint8_t val) { eeprom_write_byte((uint8_t *)idx, val); }
  void update(int idx, uint8_t val) { eeprom_update_byte((uint8_t *)idx, val); }
  template <typename T> T &get(int idx, T &t) {
    eeprom_read_block(&t, (const void *)idx, sizeof(T));
    return t;
  }
  template <typename T> const T &put(int idx, const T &t) {
    eeprom_update_block(&t, (void *)idx, sizeof(T));
    return t;
  }
};

static EEPROMLite EEPROM;

#endif
