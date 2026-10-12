#!/bin/bash
# size_build.sh -- build the CEC firmware for an ATmega328P (Raduino Nano)
# without the Arduino IDE and print its flash and RAM use.
#
#   tools/size_build.sh [DISPLAY] [BOARD]
#     DISPLAY  one of the UBITX_DISPLAY_* options in ubitx.h (default LCD1602P)
#     BOARD    UBITX_BOARD_VERSION (default 4)
#
# Needs avr-gcc, avr-libc, universal-ctags and git. Fetches ArduinoCore-avr
# into $CORE (default ~/.cache/ArduinoCore-avr). Mimics the IDE: the .ino
# files are joined (main sketch first, then the rest by name), prototypes
# come from ctags on the joined sketch, -Os with LTO and gc-sections.
# The IDE's own numbers may differ by a few hundred bytes.
set -e
DISPLAY_OPT=${1:-UBITX_DISPLAY_LCD1602P}
BOARD=${2:-4}
HERE=$(cd "$(dirname "$0")/.." && pwd)
CORE=${CORE:-$HOME/.cache/ArduinoCore-avr}
[ -d "$CORE" ] || git clone -q --depth 1 https://github.com/arduino/ArduinoCore-avr.git "$CORE"
W=$(mktemp -d)
trap 'rm -rf "$W"' EXIT
cp "$HERE"/ubitx_20/* "$W"/
cd "$W"
# select the display and board in the copy only
sed -i -E 's@^(#define UBITX_DISPLAY_[A-Z0-9_]+)([ \t]|$)@//\1\2@' ubitx.h
sed -i -E "s@^//(#define ${DISPLAY_OPT})([ \t]|\$)@\1\2@" ubitx.h
sed -i -E "s@^#define UBITX_BOARD_VERSION [0-9]+@#define UBITX_BOARD_VERSION ${BOARD}@" ubitx.h
grep -q "^#define ${DISPLAY_OPT}" ubitx.h || { echo "no display option ${DISPLAY_OPT}" >&2; exit 1; }

F="-mmcu=atmega328p -DF_CPU=16000000L -DARDUINO=10819 -DARDUINO_AVR_NANO -DARDUINO_ARCH_AVR -Os -ffunction-sections -fdata-sections -flto -w"
I="-I$CORE/cores/arduino -I$CORE/variants/eightanaloginputs -I$CORE/libraries/Wire/src -I$CORE/libraries/EEPROM/src -I$CORE/libraries/SoftwareSerial/src -I."
XX="-fno-exceptions -fno-threadsafe-statics -fpermissive"

{ echo '#include <Arduino.h>'; cat ubitx_20.ino
  for f in $(ls *.ino | grep -v '^ubitx_20.ino$' | sort); do echo "#line 1 \"$f\""; cat "$f"; done; } > sketch.cpp
ctags --kinds-C++=f --fields=+Ste --language-force=C++ -o - sketch.cpp \
  | awk -F'\t' '{ n=$1; sig=""; ret="";
      for (i=4;i<=NF;i++) { if ($i ~ /^signature:/) sig=substr($i,11); if ($i ~ /^typeref:typename:/) ret=substr($i,18); if ($i ~ /^(class|struct):/) next }
      if (n != "setup" && n != "loop" && sig != "") print ret " " n sig ";" }' | sort -u > protos.h
{ echo '#include <Arduino.h>'; echo '#include "ubitx.h"'; cat protos.h; } > pre.h

objs=""
for f in "$CORE"/cores/arduino/*.c "$CORE"/libraries/Wire/src/utility/twi.c; do
  avr-gcc $F $I -c "$f" -o "$(basename "$f").o"; objs="$objs $(basename "$f").o"; done
for f in "$CORE"/cores/arduino/*.cpp "$CORE"/libraries/Wire/src/Wire.cpp; do
  avr-g++ $F $XX $I -c "$f" -o "$(basename "$f").o"; objs="$objs $(basename "$f").o"; done
avr-g++ $F $XX $I -include pre.h -c sketch.cpp -o sketch.o
avr-g++ $F $XX $I -c softserial_tiny.cpp -o softserial_tiny.o
avr-gcc-ar rcs core.a $objs   # an archive, as the IDE links the core
avr-gcc $F -Wl,--gc-sections -o fw.elf sketch.o softserial_tiny.o core.a -lm
echo "${DISPLAY_OPT} board ${BOARD}: flash $(avr-size -A fw.elf | awk '/^\.text|^\.data/ {s+=$2} END {print s}') B (limit 30720 old bootloader, 32256 Optiboot), RAM $(avr-size -A fw.elf | awk '/^\.data|^\.bss/ {s+=$2} END {print s}') B of 2048"
if [ -n "$KEEP_ELF" ]; then cp fw.elf "$KEEP_ELF"; fi
