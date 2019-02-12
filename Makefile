#
# Define ASAN=1 to enable AddressSanitizer
#
# Define VERBOSE=1 for a more verbose compilation
#
# Define NO_LX=1 if you do not want to build jgmenu-lx (which requires
# libmenu-cache >=v1.1)
#

REQUIRED_BINS := pkg-config $(CC) xml2-config
$(foreach bin,$(REQUIRED_BINS), \
        $(if $(shell type $(bin) 2>/dev/null),, \
                $(error fatal: could not find '$(bin)')))

REQUIRED_LIBS := x11 xrandr cairo pango pangocairo librsvg-2.0
$(foreach lib,$(REQUIRED_LIBS), \
        $(if $(shell pkg-config $(lib) && echo 1),, \
                $(error fatal: could not find library '$(lib)')))

VER      = $(shell ./scripts/version-gen.sh)

# Allow user to override build settings without making tree dirty
-include config.mk

RM       = rm -f

prefix    ?= /usr/local
bindir     = $(prefix)/bin
libexecdir = $(prefix)/lib/jgmenu

ifeq ($(prefix),$(HOME))
datarootdir= $(prefix)/.local/share
else
datarootdir= $(prefix)/share
endif

CFLAGS  += -g -Wall -Os -std=gnu89
CFLAGS  += -Wextra -Wdeclaration-after-statement -Wno-format-zero-length \
	   -Wold-style-definition -Woverflow -Wpointer-arith \
	   -Wstrict-prototypes -Wunused -Wvla -Wunused-result
CFLAGS  += -Wno-unused-parameter
CFLAGS  += -DVERSION='"$(VER)"'

jgmenu:     CFLAGS  += `pkg-config cairo pango pangocairo librsvg-2.0 --cflags`
jgmenu-ob:  CFLAGS  += `xml2-config --cflags`
jgmenu-lx:  CFLAGS  += `pkg-config --cflags glib-2.0 libmenu-cache`

jgmenu:     LIBS += `pkg-config x11 xrandr cairo pango pangocairo librsvg-2.0 --libs`
jgmenu:     LIBS += -pthread -lpng
jgmenu-ob:  LIBS += `xml2-config --libs`
jgmenu-lx:  LIBS += `pkg-config --libs glib-2.0 libmenu-cache`

LDFLAGS += $(LIBS)

ifdef ASAN
ASAN_FLAGS = -O0 -fsanitize=address -fno-common -fno-omit-frame-pointer -rdynamic
CFLAGS    += $(ASAN_FLAGS)
LDFLAGS   += $(ASAN_FLAGS) -fuse-ld=gold
endif

ifndef VERBOSE
QUIET_CC   = @echo '     CC    '$@;
QUIET_LINK = @echo '     LINK  '$@;
endif

DEPDIR := .d
$(shell mkdir -p $(DEPDIR) >/dev/null)
DEPFLAGS = -MT $@ -MMD -MP -MF $(DEPDIR)/$*.Td

SCRIPTS_SHELL  = src/jgmenu_run src/jgmenu-init.sh
FRAGMENTS      = noncore/config/jgmenurc
SCRIPTS_PYTHON = src/jgmenu-pmenu.py src/jgmenu-unity-hack.py \
                 noncore/config/jgmenu-config.py

PROGS	 = jgmenu jgmenu-ob jgmenu-socket jgmenu-i18n jgmenu-greeneye

# wrap in ifneq to ensure we respect user defined NO_LX=1
ifneq ($(NO_LX),1)
NO_LX := $(shell pkg-config "libmenu-cache >= 1.1.0" "glib-2.0" || echo "1")
endif
ifneq ($(NO_LX),1)
PROGS += jgmenu-lx
endif

objects = $(patsubst ./src/%.c,%.o,$(shell find ./src -maxdepth 1 -name '*.c' -print))
mains = $(patsubst src/%,%.o,$(PROGS))
ifneq ($(NO_LX),1)
OBJS = $(filter-out $(mains),$(objects))
else
OBJS = $(filter-out $(mains) jgmenu-lx.o,$(objects))
endif
SRCS = $(patsubst %.o,src/%.c,$(OBJS))

all: $(PROGS)

jgmenu: jgmenu.o x11-ui.o config.o util.o geometry.o isprog.o sbuf.o \
	icon-find.o icon.o xpm-loader.o xdgdirs.o xsettings.o \
	xsettings-helper.o filter.o compat.o lockfile.o argv-buf.o t2conf.o \
	t2env.o unix_sockets.o bl.o cache.o back.o terminal.o restart.o \
	theme.o gtkconf.o font.o args.o widgets.o pm.o socket.o workarea.o \
	charset.o watch.o spawn.o
jgmenu-ob: jgmenu-ob.o util.o sbuf.o i18n.o hashmap.o
jgmenu-socket: jgmenu-socket.o util.o sbuf.o unix_sockets.o socket.o
ifneq ($(NO_LX),1)
jgmenu-lx: jgmenu-lx.o util.o sbuf.o xdgdirs.o argv-buf.o back.o fmt.o
endif
jgmenu-i18n: jgmenu-i18n.o i18n.o hashmap.o util.o sbuf.o
jgmenu-greeneye: jgmenu-greeneye.o compat.o

$(PROGS):
	$(QUIET_LINK)$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS)

%.o : src/%.c
%.o : src/%.c $(DEPDIR)/%.d
	$(QUIET_CC)$(CC) $(DEPFLAGS) $(CFLAGS) -c $<
	@mv -f $(DEPDIR)/$*.Td $(DEPDIR)/$*.d && touch $@

$(DEPDIR)/%.d: ;
.PRECIOUS: $(DEPDIR)/%.d

install: $(PROGS)
	@install -d $(DESTDIR)$(bindir)
	@install -m755 jgmenu src/jgmenu_run $(DESTDIR)$(bindir)
	@install -d $(DESTDIR)$(libexecdir)
	@install -m755 $(PROGS) $(SCRIPTS_SHELL) $(DESTDIR)$(libexecdir)
	@install -m755 $(SCRIPTS_PYTHON) $(DESTDIR)$(libexecdir)
	@install -m644 $(FRAGMENTS) $(DESTDIR)$(libexecdir)
	@./scripts/set-exec-path.sh $(DESTDIR)$(bindir)/jgmenu_run $(libexecdir)
	@./scripts/set-exec-path.sh $(DESTDIR)$(libexecdir)/jgmenu_run $(libexecdir)
	@$(MAKE) --no-print-directory -C docs/manual/ prefix=$(prefix) install
	@install -d $(DESTDIR)$(datarootdir)/icons/hicolor/scalable/apps/
	@install -d $(DESTDIR)$(datarootdir)/applications/
	@install -m644 ./data/jgmenu.svg $(DESTDIR)$(datarootdir)/icons/hicolor/scalable/apps/
	@install -m644 ./data/jgmenu.desktop $(DESTDIR)$(datarootdir)/applications/
ifeq ($(NO_LX),1)
	@echo "info: lx module not included as libmenu-cache >=1.1.0 not found"
endif

# We are not brave enough to uninstall in /usr/, /usr/local/ etc
uninstall:
ifneq ($(prefix),$(HOME))
	@$(error uninstall only works if prefix=$(HOME))
endif
	@rm -f ~/bin/jgmenu
	@rm -f ~/bin/jgmenu_run
	@rm -rf ~/lib/jgmenu/
	@-rmdir ~/lib 2>/dev/null || true
	@rm -f ~/share/man/man1/jgmenu*
	@rm -f ~/share/man/man7/jgmenu*
	@-rmdir ~/share/man/man1 2>/dev/null || true
	@-rmdir ~/share/man/man7 ~/share/man ~/share 2>/dev/null || true
	@rm -f ~/.local/share/icons/hicolor/scalable/apps/jgmenu.svg
	@rm -f ~/.local/share/applications/jgmenu.desktop
	@-rmdir ~/.local/share/applications 2>/dev/null || true
	@-rmdir ~/.local/share/icons/hicolor/scalable/apps 2>/dev/null || true
	@-rmdir ~/.local/share/icons/hicolor/scalable 2>/dev/null || true
	@-rmdir ~/.local/share/icons/hicolor 2>/dev/null || true
	@-rmdir ~/.local/share/icons 2>/dev/null || true

clean:
	@$(RM) $(PROGS) *.o *.a $(DEPDIR)/*.d
	@$(RM) -r .d/
	@$(MAKE) --no-print-directory -C tests/ clean
	@$(MAKE) --no-print-directory -C tests/helper/ clean

test: $(OBJS)
	@$(MAKE) --no-print-directory -C tests/helper/ all
	@$(MAKE) --no-print-directory -C tests/ all

ex:
	@$(MAKE) --no-print-directory -C examples/ all

check:
	@./scripts/checkpatch-wrapper.sh src/*.c
	@./scripts/checkpatch-wrapper.sh src/*.h

print-%:
	@echo '$*=$($*)'

include $(wildcard $(patsubst %,$(DEPDIR)/%.d,$(basename $(SRCS))))
