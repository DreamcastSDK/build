# KallistiOS ##version##
#
# examples/dreamcast/sd/ext2fs/Makefile
#

TARGET = sd-ext2fs.elf
OBJS = sd-ext2fs.o

# Uncomment the next line to enable write support in the example.
#KOS_CFLAGS += -DENABLE_WRITE

all: rm-elf $(TARGET)

include $(KOS_BASE)/Makefile.rules

clean:
	-rm -f $(TARGET) $(OBJS) romdisk.*

rm-elf:
	-rm -f $(TARGET) romdisk.*

$(TARGET): $(OBJS)
	kos-cc -o $(TARGET) $(OBJS) -lkosext2fs

run: $(TARGET)
	$(KOS_LOADER) $(TARGET)

dist:
	rm -f $(OBJS) romdisk.o romdisk.img
	$(KOS_STRIP) $(TARGET)
