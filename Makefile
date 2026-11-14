# Build libmruby.a for mrb.cr.
#
# Requirements:
#   - Ruby >= 3.0 with Rake (build time only)
#   - a C toolchain (clang or gcc)
#   - bison and gperf only when regenerating the parser from a grammar change
#     (release tags ship a pregenerated y.tab.c)
#
# Usage:
#   make            # fetch mruby 4.0.0 and build lib/libmruby.a
#   make clean      # remove the local mruby checkout and copied library
#
# Use RUBY=/path/to/ruby when the default `ruby` is older than 3.0.

MRUBY_VERSION ?= 4.0.0
MRUBY_REPO    ?= https://github.com/mruby/mruby.git
MRUBY_DIR     ?= vendor/mruby
MRUBY_BUILD   ?= host
RUBY          ?= ruby
CC            ?= cc
CFLAGS        ?= -O2 -fPIC
JOBS          ?= 4

MRUBY_STAMP := $(MRUBY_DIR)/.mrb-cr-$(MRUBY_VERSION)
MRUBY_INC   := $(MRUBY_DIR)/include
MRUBY_BUILD_INC := $(MRUBY_DIR)/build/$(MRUBY_BUILD)/include
MRUBY_LIB   := $(MRUBY_DIR)/build/$(MRUBY_BUILD)/lib/libmruby.a
LIB_DIR     := lib
DEST_LIB    := $(LIB_DIR)/libmruby.a
DEST_LIB_WIN := $(LIB_DIR)/libmruby.lib
SHIM_SRC    := src/mrb/shim.c
SHIM_OBJ    := $(LIB_DIR)/mrb_shim.o
SHIM_OBJ_WIN := $(LIB_DIR)/mrb_shim.obj
MRUBY_CONFIG_SRC := $(CURDIR)/build_config/mrb_cr.rb
MRUBY_CONFIG_WRITABLE := $(MRUBY_DIR)/build/mrb_cr.rb

.PHONY: all mruby clean distclean check examples bench asan

all: $(DEST_LIB) $(SHIM_OBJ)

$(MRUBY_STAMP):
	@mkdir -p $(dir $(MRUBY_DIR))
	@if [ -d "$(MRUBY_DIR)/.git" ]; then \
		cd $(MRUBY_DIR) && git fetch --depth 1 origin tag $(MRUBY_VERSION) && git checkout -q $(MRUBY_VERSION); \
	else \
		git clone --depth 1 --branch $(MRUBY_VERSION) $(MRUBY_REPO) $(MRUBY_DIR); \
	fi
	@touch $@

mruby: $(MRUBY_STAMP)

$(MRUBY_LIB): $(MRUBY_STAMP) build_config/mrb_cr.rb
	@mkdir -p $(MRUBY_DIR)/build
	cp $(MRUBY_CONFIG_SRC) $(MRUBY_CONFIG_WRITABLE)
	cd $(MRUBY_DIR) && MRUBY_CONFIG=build/mrb_cr.rb $(RUBY) -S rake -j$(JOBS)

$(DEST_LIB): $(MRUBY_LIB)
	@mkdir -p $(LIB_DIR)
	cp $(MRUBY_LIB) $(DEST_LIB)
	@if [ -n "$$WINDIR" ] || [ "$(OS)" = "Windows_NT" ]; then cp $(DEST_LIB) $(DEST_LIB_WIN); fi

$(SHIM_OBJ): $(SHIM_SRC) $(MRUBY_LIB)
	@mkdir -p $(LIB_DIR)
	$(CC) $(CFLAGS) -I$(MRUBY_INC) -I$(MRUBY_BUILD_INC) -c $(SHIM_SRC) -o $(SHIM_OBJ)
	@if [ -n "$$WINDIR" ] || [ "$(OS)" = "Windows_NT" ]; then cp $(SHIM_OBJ) $(SHIM_OBJ_WIN); fi

check: $(DEST_LIB) $(SHIM_OBJ)
	crystal tool format --check
	crystal spec

ASAN_FLAGS ?= -fsanitize=address -fno-omit-frame-pointer -g

examples: $(DEST_LIB) $(SHIM_OBJ)
	crystal run examples/calculator.cr
	crystal run examples/host_callback.cr
	crystal run examples/json_values.cr

bench: $(DEST_LIB) $(SHIM_OBJ)
	crystal run --release benchmark/bench.cr

# Rebuilds mruby and the shim with AddressSanitizer, then runs the specs.
# Run `make clean && make` afterwards to restore the normal build.
asan:
	$(MAKE) clean
	MRUBY_ASAN=1 $(MAKE) CFLAGS="-O1 $(ASAN_FLAGS)"
	ASAN_OPTIONS=detect_leaks=0 crystal spec --link-flags "$(ASAN_FLAGS)"

clean:
	rm -f $(DEST_LIB) $(SHIM_OBJ)
	rm -rf $(MRUBY_DIR)/build

distclean: clean
	rm -rf $(MRUBY_DIR)
