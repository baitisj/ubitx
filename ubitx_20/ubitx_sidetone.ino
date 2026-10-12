/*************************************************************************
  Sidetone for the QRSS fork: a small replacement for Arduino's tone().

  tone() handles any pin, any timer and a duration, which costs about
  1.2 KB of flash. CEC only ever sounds CW_TONE (D6, PD6) until it is
  stopped, so this runs Timer2 in CTC mode and toggles PD6 from the
  compare interrupt, as tone() does, with the smallest prescaler that fits.
  Timer2 stays free otherwise; Timer0 keeps millis().
**************************************************************************/
#include "ubitx.h"

void sidetoneOn(unsigned int hz)
{
  static const uint8_t shifts[7] = {0, 3, 5, 6, 7, 8, 10}; //prescaler 1 ~ 1024
  unsigned long ocr;
  uint8_t cs = 1;

  if (hz == 0)
    return;
  do {
    ocr = (F_CPU / 2 / hz >> shifts[cs - 1]) - 1;
  } while (ocr > 255 && ++cs <= 7);
  if (cs > 7) {
    cs = 7;
    ocr = 255;
  }
  TIMSK2 = 0;
  TCCR2A = _BV(WGM21);    //CTC
  TCCR2B = cs;
  OCR2A = (uint8_t)ocr;
  TCNT2 = 0;
  TIMSK2 = _BV(OCIE2A);
}

void sidetoneOff(void)
{
  TIMSK2 = 0;
  PORTD &= ~_BV(6);       //CW_TONE low, as noTone() leaves it
}

ISR(TIMER2_COMPA_vect)
{
  PIND = _BV(6);          //toggle CW_TONE (D6)
}
