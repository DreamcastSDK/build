# KallistiOS ##version##
#
# basic/threading/recursive_lock/Makefile
# Copyright (C) 2008 Lawrence Sebald
#

all: rm-elf rlock_test.elf

include $(KOS_BASE)/Makefile.rules

OBJS = rlock_test.o

clean: rm-elf
	-rm -f $(OBJS)

rm-elf:
	-rm -f rlock_test.elf

rlock_test.elf: $(OBJS)
	$(KOS_CC) $(KOS_CFLAGS) $(KOS_LDFLAGS) -o rlock_test.elf $(KOS_START) \
	$(OBJS) $(DATAOBJS) $(OBJEXTRA) $(KOS_LIBS)


run: rlock_test.elf
	$(KOS_LOADER) rlock_test.elf

dist:
	rm -f $(OBJS)
	$(KOS_STRIP) rlock_test.elf