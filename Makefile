.PHONY: install uninstall

ifeq ($(PREFIX),)
    PREFIX := /usr/local
endif

install: whaleboot.sh
	install -d $(DESTDIR)$(PREFIX)/bin/
	install -m 755 whaleboot.sh $(DESTDIR)$(PREFIX)/bin/whaleboot

uninstall:
	rm $(DESTDIR)$(PREFIX)/bin/whaleboot
