#!/bin/sh -e
umask 077
set -e
set -x

SCRIPT=$(realpath $0)
CODE=$(realpath $0/../decode.c)
EXTRACT=$(realpath $0/../extract.sh)
DIR=$(dirname $CODE)
EXPDIR=`pwd`
PASSWD=${PASSWD:-}
PIN=$(openssl rand -base64 128 | tr -dc 0-9 | cut -c 1-4)

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

# Disable the agent - as it will prevent us from unmounting the
# disk post generation due to it claiming a socket.
#
echo no-use-agent > gpg.conf

# generate a private/public keypair; and export it. We use ED25519
# as to allow it ti fit in a QR code (hence we keep the name short too).
#
gpg2 --homedir . --batch --passphrase "$PASSWD" --quick-generate-key key-$$ ed25519
FPR=$(gpg --homedir . --list-keys --with-colons key-$$| grep fpr | head -1 | cut -f 10 -d:)
gpg2 --homedir . --batch --passphrase "$PASSWD" --quick-add-key $FPR cv25519 

# test that we can encrupt
echo All working ok | gpg2 --homedir . --encrypt  --batch --passphrase "$PASSWD" -r key-$$ > test.gpg
gpg2 --homedir . --decrypt < test.gpg

gpg2 --homedir . --batch --passphrase "$PASSWD" --export-options export-minimal --export-secret-keys key-$$  > gpg.priv.raw
gpg2 --homedir . --batch --passphrase "$PASSWD" --export-options export-minimal -a --export-secret-keys key-$$  > gpg.priv.raw.asc

# Encode the private key to both a hexdump and a QR code.
#
qrencode -l H -8 -s 8 -r gpg.priv.raw -o qr.png
hexdump gpg.priv.raw  > priv.txt

# Decode the key and check that it is identical
#
qrdecode qr.png > gpg.priv.raw.dec # quirc v1.00
diff gpg.priv.raw.dec gpg.priv.raw

# Import the key into a fresh keyring - to verify that that works.
#
mkdir test.$$
gpg2 --homedir test.$$ --batch --passphrase "$PASSWD" --import gpg.priv.raw.dec
gpg2 --homedir test.$$ --batch --passphrase "$PASSWD" --decrypt test.gpg

gpg2 --homedir . --batch --passphrase "$PASSWD" --list-keys  --fingerprint --with-subkey-fingerprint > gpg.txt
rm -rf test.$$

(
	uname -a
	echo
	gpg --version
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
SHA256=`openssl sha256 gpg.priv.raw |sed -e "s/.*= //" -e 's/\(........\)/ \1/g'`
SHA256A=`openssl sha256 gpg.priv.raw.asc |sed -e "s/.*= //" -e 's/\(........\)/ \1/g'`

KEYNAME=$$

SPECIMEN=""
if [ "x$1" = 'x-d' ]; then
	SPECIMEN="SPECIMEN"
fi

export CODE SHA256 SHA256A KEYNAME DATE SCRIPT EXTRACT SPECIMEN
cat $DIR/doc.tex | envsubst > privkey.tex

/usr/local/texlive/2018/bin/x86_64-darwin/pdflatex privkey.tex
/usr/local/texlive/2018/bin/x86_64-darwin/pdflatex privkey.tex

if [ "x$1" = 'x-d' ]; then
	open privkey.pdf
else
lpr -\# 2 \
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
gpg2 --homedir . --export key-$$ >  $EXPDIR/public-key-$$.gpg

# Ejecting the ephemeral disk will wipe all private key material.
# We use 'force' to foil MDS.
#
hdiutil eject -force $OUTDIR

echo
echo
echo Printer PIN is $PIN

exit 0
