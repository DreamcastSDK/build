# KallistiOS ##version##
#
# lightgun/basic/Makefile
#

all: rm-elf lightgun.elf

include $(KOS_BASE)/Makefile.rules

TARGET = lightgun.elf
OBJS = lightgun.o

clean:
	-rm -f $(TARGET) $(OBJS)

rm-elf:
	-rm -f $(TARGET)

$(TARGET): $(OBJS)
	kos-cc -o $(TARGET) $(OBJS) $(DATAOBJS) $(OBJEXTRA)

run: $(TARGET)
	$(KOS_LOADER) $(TARGET)

dist:
	-rm -f $(OBJS)
	$(KOS_STRIP) $(TARGET)
