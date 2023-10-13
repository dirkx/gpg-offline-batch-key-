#!/bin/sh -e
umask 077
set -e

if  test -e /dev/cu.usbserial-1337_BFBF0B95; then
	echo Hardware random generator not plugged in/visible to virtual host
	exit 1
fi

SCRIPT=$(realpath $0)
CODE=$(realpath $0/../decode.c)
EXTRACT=$(realpath $0/../extract.sh)
DIR=$(dirname $CODE)
EXPDIR=`pwd`
PASSWD=${PASSWD:-}
PIN=$(openssl rand -base64 128 | tr -dc 0-9 | cut -c 1-4)
WW=$(openssl rand -base64 128 | tr -dc 0-9a-zA-Z | cut -c 1-12)

# create an ephemeral disk that disappears once we're done.
#
openssl rand -base64 128 | hdiutil create -attach -stdinpass \
	-encryption -size 1M -fs HFS+ -volname tmp.$$ tmp.$$ 
rm tmp.$$.dmg
OUTDIR=/Volumes/tmp.$$

# Switch off spotlight indexing; and then disable it.
mdutil -d -i off $OUTDIR

# create and from hereon work on that ephemeral disk; that should
# disappear once we're done.
#
test -d $OUTDIR
chmod 700 $OUTDIR
cd $OUTDIR

openssl req -new -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -x509 -nodes -days 3650 -out cert.pem -keyout cert.pem -subj /CN="fakeGAEN"
openssl ec -in cert.pem > secret-key.pem
openssl ec -in cert.pem -outform DER > secret-key.der
openssl ec -in cert.pem -pubout > pub-key.pem
openssl ec -in cert.pem -pubout -outform DER > pub-key.der
openssl pkcs12 -in cert.pem -export -out cert.p12 -nodes -password pass:
openssl pkcs12 -in cert.pem -export -out bundle.p12 -nodes -password pass:$WW

# Extract the EC key...include in OS
openssl ec -in cert.pem -pubout | openssl ec -pubin -text > pub.txt
openssl ec -in cert.pem -text -pubout > priv.txt

qrencode -l H -8 -s 8 -r secret-key.der -o qr.png
hexdump secret-key.der  > privhex.txt

SHA256=`openssl sha256 secret-key.der  |sed -e "s/.*= //" -e 's/\(........\)/ \1/g'`
SHA256A=`openssl sha256 secret-key.pem |sed -e "s/.*= //" -e 's/\(........\)/ \1/g'`

# Decode the key and check that it is identical
#
qrdecode qr.png > secret-key.der.dec # quirc v1.00
diff  secret-key.der.dec  secret-key.der 


(
	uname -a
	echo
	openssl version
	echo
	qrencode --version
	echo
	echo quirc
	echo "Copyright (C) 2010-2012 Daniel Beer <dlbeer@gmail.com>"
	echo Library version: 1.0
) > info.txt
# Generare the various pages.
#
DATE=`date -u`


SPECIMEN=""
if [ "x$1" = 'x-d' ]; then
	SPECIMEN="SPECIMEN"
	shift
fi
KEYNAME="key-$$"
if [ $# -gt 0 ]; then
	KEYNAME="$*"
fi

export CODE SHA256 SHA256A KEYNAME DATE SCRIPT EXTRACT SPECIMEN WW
cat $DIR/doc-unmanaged.tex | envsubst > privkey.tex

/Library/TeX/texbin/pdflatex privkey.tex
/Library/TeX/texbin/pdflatex privkey.tex

if [ "x$SPECIMEN" = 'xSPECIMEN' ]; then
	cp privkey.pdf $TMPDIR
	open $TMPDIR/privkey.pdf
else
lpr privkey.pdf

true || lpr -\# 2 \
	-o collate=true \
	-o com.brother.print.PrintSettings.secureprint=ON \
	-o com.brother.print.PrintSettings.cfjobname=key-$$ \
	-o com.brother.print.PrintSettings.cfusername=${LOGNAME:-key-$$} \
	-o com.brother.print.PrintSettings.password=$PIN \
	\
	`perl -e '($p, $f,$v)=@ARGV;$i=0; map { print "-o $p.$f..a.$i..n.=$_ "; $i++; } unpack("c*",$v);; print "-o $p.".$f."cnt=$i -o $p.cf$f=$v";' \
		com.brother.print.PrintSettings jobname key-$$` \
	`perl -e '($p, $f,$v)=@ARGV;$i=0; map { print "-o $p.$f..a.$i..n.=$_ "; $i++; } unpack("c*",$v);; print "-o $p.".$f."cnt=$i -o $p.cf$f=$v";' \
		com.brother.print.PrintSettings username ${LOGNAME:-key-$$}` \
	\
	privkey.pdf
fi
 
# Export the public key - for actual use. The private key will fromhereon 
# only exist on paper.
#
mkdir bundle-$$
cp cert.p12 cert.pem priv.txt privhex.txt pub-key.der pub-key.pem pub.txt secret-key.der secret-key.pem bundle-$$

7z -p$WW a $EXPDIR/bundle-$KEYNAME-$$.zip  bundle-$$/*
cp pub.txt $EXPDIR/bundle-$KEYNAME-$$.txt
cp bundle.p12  $EXPDIR/bundle-$KEYNAME-$$.p12

# Ejecting the ephemeral disk will wipe all private key material.
# We use 'force' to foil MDS.
#
hdiutil eject -force $OUTDIR

echo Files /bundle-$KEYNAME-$$.zip, txt en p12
echo
echo Printer PIN is $PIN
echo WW is $WW

exit 0
