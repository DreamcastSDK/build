TARGET = bump.elf
OBJS = bump.o romdisk.o

all: rm-elf $(TARGET)

include $(KOS_BASE)/Makefile.rules

clean:
	-rm -f $(TARGET) $(OBJS) romdisk.* romdisk/*.kmg romdisk/*.raw

rm-elf:
	-rm -f $(TARGET)

$(TARGET): $(OBJS)
	kos-cc -o $(TARGET) $(OBJS) -lkmg -lkosutils

romdisk.img: romdisk/bricks.kmg romdisk/bumpmap.raw
	$(KOS_GENROMFS) -f romdisk.img -d romdisk -v

romdisk.o: romdisk.img
	$(KOS_BASE)/utils/bin2o/bin2o romdisk.img romdisk romdisk.o

romdisk/bricks.kmg: bricks.png
	$(KOS_BASE)/utils/vqenc/vqenc -t -v -q -k bricks.png
	mv bricks.kmg romdisk/

romdisk/bumpmap.raw: bumpmap.png
	$(KOS_BASE)/utils/dcbumpgen/dcbumpgen $+ $@

run: $(TARGET)
	$(KOS_LOADER) $(TARGET) -n

dist:
	rm -f $(OBJS)
	$(KOS_STRIP) $(TARGET)
