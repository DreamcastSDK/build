/*   
   dcbumpgen - creates polar angles to be used for bumpmapping
   Copyright (c) 2005 Fredrik Ehnbom

   This software is provided 'as-is', without any express or implied 
   warranty. In no event will the authors be held liable for any 
   damages arising from the use of this software.

   Permission is granted to anyone to use this software for any 
   purpose, including commercial applications, and to alter it and 
   redistribute it freely, subject to the following restrictions:

   1. The origin of this software must not be misrepresented; you 
      must not claim that you wrote the original software. If you use
      this software in a product, an acknowledgment in the product 
      documentation would be appreciated but is not required.

   2. Altered source versions must be plainly marked as such, and 
      must not be misrepresented as being the original software.

   3. This notice may not be removed or altered from any source 
      distribution.
 */
#include <stdio.h>
#include <stdlib.h>
#include <math.h>

/* TODO:
 * With this utility included, there are now three utilities
 * (the other two being "vqenc" and "kmgenc") using common texture
 * operations such as twiddling and loading of png and jpeg images.
 * Maybe it is time to break that stuff out into its own library
 * or create a megatool consisting of all the tree tools in one
 * executable.
 */
#include "get_image.h"

void printUsage() {
	printf("dcbumpgen - Dreamcast bumpmap generator v0.1\n");
	printf("Copyright (c) 2005 Fredrik Ehnbom\n");
	printf("usage: dcbumpgen <infile.png/.jpg> <outfile.raw>\n");
}

/* twiddling stuff copied from kmgenc.c */
#define TWIDTAB(x) ( (x&1)|((x&2)<<1)|((x&4)<<2)|((x&8)<<3)|((x&16)<<4)| \
	((x&32)<<5)|((x&64)<<6)|((x&128)<<7)|((x&256)<<8)|((x&512)<<9) )
#define TWIDOUT(x, y) ( TWIDTAB((y)) | (TWIDTAB((x)) << 1) )
#define MIN(a, b) ( (a)<(b)? (a):(b) )

int main(int argc, char **argv) {
	image_t img;
	FILE *fp;
	int y, x;
	unsigned char *buffer;
	int imgpos, dest;

	if (argc != 3) {
		printUsage();
		exit(1);
	}

	if (get_image(argv[1], &img) < 0) {
		fprintf(stderr, "couldn't open %s\n", argv[1]);
		return -1;
	}

	/* TODO:
	 * - error-checking for missing files and other file failures
	 * - check that image is power of two
	 */
	fp = fopen(argv[2], "wb");
	buffer = malloc(2 * img.w * img.h);

	imgpos = 1; /* 1 to skip the alpha-channel */
	dest = 0;
	for (y = 0; y < img.h; y++) {
		for (x = 0; x < img.w; x++, imgpos += 4) {
			double diffy = 0;
			double diffx = 0;
			if (y > 0 && x > 0) {
				diffy = (img.data[imgpos - img.stride] - img.data[imgpos]) / 255.0;
				diffx = (img.data[imgpos - 4] - img.data[imgpos]) / 255.0;
			}

			/* Rotation = R
			   0 -> almost 360 degrees */
			double rot = atan2(diffy, diffx);
			int rotation = (int) ((rot / (2 * 3.1415927)) * 255);

			/* Elevation = S
			   0 -> almost 90 degrees */
			int elevation = (int) (255 * (1 - fabs(diffx) - fabs(diffy)));
			if (elevation < 0) elevation = 0;

			buffer[dest] = rotation; dest++;
			buffer[dest] = elevation; dest++;
		}
	}

	/* twiddle code based on code from kmgenc.c */
	int min = MIN(img.w, img.h);
	int mask = min-1;
	short *sbuffer = (short*) buffer;
	short *twidbuffer = malloc(2 * img.w * img.h);
	for (y=0; y<img.h; y++) {
		int yout = y;
		for (x=0; x<img.w; x++) {
			twidbuffer[TWIDOUT(x&mask, yout&mask) +
				(x/min + yout/min)*min*min] = sbuffer[y*img.w+x];
		}
	}

	fwrite(twidbuffer, 1, 2* img.w * img.h, fp);
	fclose(fp);

	free(buffer);
	free(twidbuffer);
	if (img.data) {
		free(img.data);
	}
	return 0;
}

