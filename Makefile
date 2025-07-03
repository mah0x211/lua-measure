# Package name
PACKAGE_NAME = measure

# Source files - simple and recursive
CSRCS = $(shell find src -name '*.c')
COBJS = $(CSRCS:.c=.$(LIB_EXTENSION))
CLIBS = $(patsubst src/%,$(INST_CLIBDIR)/%,$(COBJS))

LUASRCS = $(shell find lib -name '*.lua')
LUALIBS = $(patsubst lib/%,$(INST_LUALIBDIR)/%,$(filter-out lib/$(PACKAGE_NAME).lua,$(LUASRCS)))
MAINLIB = $(if $(wildcard lib/$(PACKAGE_NAME).lua),$(INST_LUADIR)/$(PACKAGE_NAME).lua)

# Install directories
INST_LUALIBDIR = $(INST_LUADIR)/$(PACKAGE_NAME)
INST_CLIBDIR = $(INST_LIBDIR)/$(PACKAGE_NAME)

# Coverage flags
ifdef MEASURE_COVERAGE
COVFLAGS = --coverage
endif

.PHONY: all install clean show-vars test

all: $(COBJS)

clean:
	rm -f $(COBJS)
	find src -name "*.o" -delete
	find src -name "*.gcda" -delete
	find src -name "*.gcno" -delete

%.o: %.c
	$(CC) $(CFLAGS) $(WARNINGS) $(COVFLAGS) $(CPPFLAGS) -o $@ -c $<

%.$(LIB_EXTENSION): %.o
	$(CC) -o $@ $^ $(LDFLAGS) $(PLATFORM_LDFLAGS) $(COVFLAGS)

# Common installation rule
define INSTALL_LIBS
	@mkdir -p $(@D)
	@echo "Installing $< -> $@"
	@install $< $@
endef

# Lua files installation
$(INST_LUALIBDIR)/%: lib/%
	$(INSTALL_LIBS)

ifneq ($(MAINLIB),)
$(MAINLIB): lib/$(PACKAGE_NAME).lua
	$(INSTALL_LIBS)
endif

# C libraries installation - pattern rule magic!
$(INST_CLIBDIR)/%: src/%
	$(INSTALL_LIBS)

# Install all
install: $(LUALIBS) $(MAINLIB) $(CLIBS)
	@echo "Installation complete"
	# Clean up .so, .o and .gcda files in the source directory
	find src -name "*.so" -delete
	find src -name "*.o" -delete
	find src -name "*.gcda" -delete

# Debug variables
show-vars:
	@echo "=== Build Variables ==="
	@echo "CSRCS: $(CSRCS)"
	@echo "COBJS: $(COBJS)"
	@echo "CLIBS: $(CLIBS)"
	@echo "LUASRCS: $(LUASRCS)"
	@echo "LUALIBS: $(LUALIBS)"

# Test functionality
test: all
	@echo "Running tests..."
	testcase test/
