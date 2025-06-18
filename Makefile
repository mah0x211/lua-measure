# Package name
PACKAGE_NAME = measure

# Source files
SRCS = $(wildcard src/*.c)
SOBJ = $(SRCS:.c=.$(LIB_EXTENSION))
LUASRCS = $(shell find lib -name '*.lua')

# Install directories
INST_LUALIBDIR = $(INST_LUADIR)/$(PACKAGE_NAME)
INST_CLIBDIR = $(INST_LIBDIR)/$(PACKAGE_NAME)
LUALIBS = $(patsubst lib/%,$(INST_LUALIBDIR)/%,$(LUASRCS))

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

$(INST_LUALIBDIR)/%: lib/%
	@mkdir -p $(@D)
	@echo "Installing $< -> $@"
	@install $< $@

install: $(LUALIBS)
	@echo "Installing Lua libraries to $(INST_LUALIBDIR)..."
ifneq ($(strip $(SRCS)),)
	@echo "Installing C libraries to $(INST_CLIBDIR)..."
	@install -d $(INST_CLIBDIR)
	@install $(SOBJ) $(INST_CLIBDIR)/
	@rm -f $(SOBJ) src/*.gcda
else
	@echo "No C source files found, skipping C library installation"
endif
