Run with

	sh gen.sh -d

and observe the results. Make sure the hardware random generator is visible
to the VM/host -or- is wired into the entropy pool. There are spare ones in
the systems draw; put them back after user.

Actual use will require editing the printer details in the script.

Nown issue:

-	The QR decoder segfaults on certain keys when compiled with -O3.

Requires
	https://github.com/dlbeer/quirc.git
	realpath
	qrencode

