CC ?= cc
PREFIX ?= /usr/local
BIN ?= figbar
VERSION ?= 0.0.5

CFLAGS += $(shell pkg-config --cflags wayland-client cairo pangocairo) \
	-Wall -Wextra -Wno-unused-parameter
LDLIBS += $(shell pkg-config --libs wayland-client cairo pangocairo) -lrt
WAYLAND_PROTOCOLS = $(shell pkg-config --variable=pkgdatadir wayland-protocols)

all:
	wayland-scanner client-header \
		$(WAYLAND_PROTOCOLS)/stable/xdg-shell/xdg-shell.xml \
		src/xdg-shell-client-protocol.h
	wayland-scanner private-code \
		$(WAYLAND_PROTOCOLS)/stable/xdg-shell/xdg-shell.xml \
		src/xdg-shell-protocol.c
	wayland-scanner client-header \
		protocols/wlr-layer-shell-unstable-v1.xml \
		src/wlr-layer-shell-unstable-v1-client-protocol.h
	wayland-scanner private-code \
		protocols/wlr-layer-shell-unstable-v1.xml \
		src/wlr-layer-shell-unstable-v1-protocol.c
	wayland-scanner client-header \
		$(WAYLAND_PROTOCOLS)/staging/fractional-scale/fractional-scale-v1.xml \
		src/fractional-scale-v1-client-protocol.h
	wayland-scanner private-code \
		$(WAYLAND_PROTOCOLS)/staging/fractional-scale/fractional-scale-v1.xml \
		src/fractional-scale-v1-protocol.c
	wayland-scanner client-header \
		$(WAYLAND_PROTOCOLS)/stable/viewporter/viewporter.xml \
		src/viewporter-client-protocol.h
	wayland-scanner private-code \
		$(WAYLAND_PROTOCOLS)/stable/viewporter/viewporter.xml \
		src/viewporter-protocol.c
	$(CC) -o $(BIN) $(CFLAGS) $(LDLIBS) \
		src/xdg-shell-protocol.c \
		src/wlr-layer-shell-unstable-v1-protocol.c \
		src/fractional-scale-v1-protocol.c \
		src/viewporter-protocol.c \
		src/shm.c \
		src/wayland.c \
		src/state.c \
		src/render.c \
		src/main.c

clean:
	rm -f $(BIN) src/xdg-shell-client-protocol.h src/xdg-shell-protocol.c \
		src/wlr-layer-shell-unstable-v1-client-protocol.h \
		src/wlr-layer-shell-unstable-v1-protocol.c \
		src/fractional-scale-v1-client-protocol.h \
		src/fractional-scale-v1-protocol.c \
		src/viewporter-client-protocol.h \
		src/viewporter-protocol.c

install: all
	mkdir -p $(PREFIX)/bin
	cp -f $(BIN) $(PREFIX)/bin

uninstall:
	rm -f $(PREFIX)/bin/$(BIN)

archive:
	git archive --format=tar.gz --prefix=figbar-$(VERSION)/ -o figbar-$(VERSION).tar.gz HEAD

.PHONY: all clean install uninstall archive
