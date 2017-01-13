# KallistiOS ##version##
#
# basic/threading/once/Makefile
# Copyright (C) 2009 Lawrence Sebald
#

all: rm-elf once_test.elf

include $(KOS_BASE)/Makefile.rules

OBJS = once_test.o

clean: rm-elf
	-rm -f $(OBJS)

rm-elf:
	-rm -f once_test.elf

once_test.elf: $(OBJS)
	$(KOS_CC) $(KOS_CFLAGS) $(KOS_LDFLAGS) -o once_test.elf $(KOS_START) \
	$(OBJS) $(DATAOBJS) $(OBJEXTRA) $(KOS_LIBS)


run: once_test.elf
	$(KOS_LOADER) once_test.elf

dist:
	rm -f $(OBJS)
	$(KOS_STRIP) once_test.elf

