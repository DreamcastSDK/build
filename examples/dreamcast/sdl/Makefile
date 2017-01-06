DIRS = sound

all:
	@for i in $(DIRS); do \
		echo "Building example $$i..."; \
		$(KOS_MAKE) -C $$i || exit -1; \
		echo ""; \
	done

clean:
	@for i in $(DIRS); do \
		echo "Cleaning example $$i..."; \
		$(KOS_MAKE) -C $$i clean || exit -1; \
		echo ""; \
	done

dist:
	@for i in $(DIRS); do \
		echo "Building example $$i (dist mode)..."; \
		$(KOS_MAKE) -C $$i dist || exit -1; \
		echo ""; \
	done
