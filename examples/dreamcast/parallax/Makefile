# KallistiOS ##version##
#
# examples/dreamcast/parallax/Makefile
# (c)2002 Dan Potter
#

TARGETS = font bubbles raster_melt sinus delay_cube rotocube

all:
	for i in $(TARGETS); do $(KOS_MAKE) -C $$i || exit -1; done

clean:
	for i in $(TARGETS); do $(KOS_MAKE) -C $$i clean || exit -1; done
		
dist:
	for i in $(TARGETS); do $(KOS_MAKE) -C $$i dist || exit -1; done


