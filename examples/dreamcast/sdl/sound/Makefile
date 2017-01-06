TARGET = sdl_sound.elf
OBJS = example.o

all: clean $(TARGET)

include $(KOS_BASE)/Makefile.rules

clean:
	-rm -f $(TARGET) $(OBJS)

$(TARGET): $(OBJS)
	kos-cc -o $(TARGET) $(OBJS) $(DATAOBJS) $(OBJEXTRA) -lSDL

run:
	$(KOS_LOADER) $(TARGET)

dist: $(TARGET)
	$(KOS_STRIP) $(TARGET)
