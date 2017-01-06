# KallistiOS ##version##
#
# basic/threading/rwsem/Makefile
# Copyright (C) 2008 Lawrence Sebald
#

all: rm-elf rwsem_test.elf

include $(KOS_BASE)/Makefile.rules

OBJS = rwsem_test.o

clean: rm-elf
	-rm -f $(OBJS)

rm-elf:
	-rm -f rwsem_test.elf

rwsem_test.elf: $(OBJS)
	$(KOS_CC) $(KOS_CFLAGS) $(KOS_LDFLAGS) -o rwsem_test.elf $(KOS_START) \
	$(OBJS) $(DATAOBJS) $(OBJEXTRA) $(KOS_LIBS)


run: rwsem_test.elf
	$(KOS_LOADER) rwsem_test.elf

dist:
	rm -f $(OBJS)
	$(KOS_STRIP) rwsem_test.elf