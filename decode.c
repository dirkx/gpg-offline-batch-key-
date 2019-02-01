#include <stdio.h>
#include <string.h>
#include <assert.h>
#include "quirc_internal.h"
#include "dbgutil.h"

int main(int argc, char **argv)
{
        struct quirc *q;

        if (argc < 2) {
                fprintf(stderr, "Usage: %s <testfile.jpg|testfile.png>\n", argv[0]);
                return -1;
        }

        q = quirc_new();
        if (!q) {
                perror("can't create quirc object");
                return -1;
        }

        int status = -1;
        if (check_if_png(argv[1])) {
                status = load_png(q, argv[1]);
        } else {
                status = load_jpeg(q, argv[1]);
        }
        if (status < 0) {
                fprintf(stderr,"loading of png/jpeg image failed: %s\n", quirc_strerror(status));
                quirc_destroy(q);
                return -1;
        }
        quirc_end(q);

	int count = quirc_count(q);
	if (count != 1) {
		fprintf(stderr,"Expected exactly one image. Got %d\n", count);
                quirc_destroy(q);
                return -1;
	};

        struct quirc_code code;
        struct quirc_data data;

        quirc_extract(q, 0, &code);
        int err = quirc_decode(&code, &data);
	if (err) {
                fprintf(stderr,"quirc decode failed: %s\n", quirc_strerror(err));
                quirc_destroy(q);
                return -1;
	};

        for(int i = 0; i < data.payload_len; i++)
                printf("%c", data.payload[i]);

        quirc_destroy(q);
        return 0;
}
