# Package name
PACKAGE_NAME = measure

# Source files
SRCS = $(wildcard src/*.c)
SOBJ = $(SRCS:.c=.$(LIB_EXTENSION))
LUASRCS = $(shell find lib -name '*.lua')

# Install directories
INST_LUALIBDIR = $(INST_LUADIR)/$(PACKAGE_NAME)
INST_CLIBDIR = $(INST_LIBDIR)/$(PACKAGE_NAME)
LUALIBS = $(patsubst lib/%,$(INST_LUALIBDIR)/%,$(filter-out lib/$(PACKAGE_NAME).lua,$(LUASRCS)))
MAINLIB = $(if $(wildcard lib/$(PACKAGE_NAME).lua),$(INST_LUADIR)/$(PACKAGE_NAME).lua)

# Coverage flags
ifdef MEASURE_COVERAGE
COVFLAGS = --coverage
endif

.PHONY: all install clean

all: $(if $(SRCS),$(SOBJ))

clean:
	rm -f $(SOBJ) src/*.o src/*.gcda src/*.gcno

%.o: %.c
	$(CC) $(CFLAGS) $(WARNINGS) $(COVFLAGS) $(CPPFLAGS) -o $@ -c $<

%.$(LIB_EXTENSION): %.o
	$(CC) -o $@ $^ $(LDFLAGS) $(PLATFORM_LDFLAGS) $(COVFLAGS)

# Common rule for installing Lua files
define INSTALL_LUA_FILE
	@mkdir -p $(@D)
	@echo "Installing $< -> $@"
	@install $< $@
endef

$(INST_LUALIBDIR)/%: lib/%
	$(INSTALL_LUA_FILE)

ifneq ($(MAINLIB),)
$(MAINLIB): lib/$(PACKAGE_NAME).lua
	$(INSTALL_LUA_FILE)
endif

install: $(LUALIBS) $(MAINLIB)
	@echo "Installing Lua libraries to $(INST_LUALIBDIR)..."
ifneq ($(MAINLIB),)
	@echo "Installing main library to $(INST_LUADIR)..."
endif
ifneq ($(strip $(SRCS)),)
	@echo "Installing C libraries to $(INST_CLIBDIR)..."
	@install -d $(INST_CLIBDIR)
	@install $(SOBJ) $(INST_CLIBDIR)/
	@rm -f $(SOBJ) src/*.gcda
else
	@echo "No C source files found, skipping C library installation"
endif
