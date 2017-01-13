# KallistiOS ##version##
#
# examples/dreamcast/dreameye/sd/Makefile
#

TARGET = dreameye-sd.elf
OBJS = dreameye-sd.o

# Compile cleanly, or die trying!
KOS_CFLAGS += -Werror -W -std=gnu99

all: rm-elf $(TARGET)

include $(KOS_BASE)/Makefile.rules

clean:
	-rm -f $(TARGET) $(OBJS)

rm-elf:
	-rm -f $(TARGET)

$(TARGET): $(OBJS)
	kos-cc -o $(TARGET) $(OBJS) -lkosext2fs

run: $(TARGET)
	$(KOS_LOADER) $(TARGET)

dist:
	rm -f $(OBJS)
	$(KOS_STRIP) $(TARGET)
