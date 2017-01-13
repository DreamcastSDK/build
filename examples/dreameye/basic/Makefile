# KallistiOS ##version##
#
# examples/dreamcast/dreameye/basic/Makefile
# Copyright (C) 2009 Lawrence Sebald
#

all: rm-elf dreameye_test.elf

include $(KOS_BASE)/Makefile.rules

OBJS = dreameye.o

clean: rm-elf
	-rm -f $(OBJS)

rm-elf:
	-rm -f dreameye_test.elf

dreameye_test.elf: $(OBJS)
	$(KOS_CC) $(KOS_CFLAGS) $(KOS_LDFLAGS) -o dreameye_test.elf $(KOS_START) \
	$(OBJS) $(DATAOBJS) $(OBJEXTRA) $(KOS_LIBS)


run: dreameye_test.elf
	$(KOS_LOADER) dreameye_test.elf

dist:
	rm -f $(OBJS)
	$(KOS_STRIP) dreameye_test.elf
