#!/bin/sh
#
set -x
set -e

mkdir extract.$$ && cd extract.$$

git clone https://github.com/dlbeer/quirc.git
( cd quirc && make )

gcc -I quirc/tests -I quirc/lib  -o decode \
	../decode.c  \
	quirc/lib/*.o quirc/tests/dbgutil.o \
	-ljpeg -lpng -lSDL

# Decode QR code.
./decode ~/Downloads/qr.png  > key.raw

# Check checksum
openssl sha256 key.raw 

# Import key.
gpg --homedir . --import key.raw 

