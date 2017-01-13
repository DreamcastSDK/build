# KallistiOS ##version##
#
# basic/threading/tls/Makefile
# Copyright (C) 2009 Lawrence Sebald
#

all: rm-elf tls_test.elf

include $(KOS_BASE)/Makefile.rules

OBJS = tls_test.o

clean: rm-elf
	-rm -f $(OBJS)

rm-elf:
	-rm -f tls_test.elf

tls_test.elf: $(OBJS)
	$(KOS_CC) $(KOS_CFLAGS) $(KOS_LDFLAGS) -o tls_test.elf $(KOS_START) \
	$(OBJS) $(DATAOBJS) $(OBJEXTRA) $(KOS_LIBS)


run: tls_test.elf
	$(KOS_LOADER) tls_test.elf

dist:
	rm -f $(OBJS)
	$(KOS_STRIP) tls_test.elf

