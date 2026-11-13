# Build libmruby.a for mrb.cr.
#
# Requirements:
#   - Ruby >= 3.0 with Rake (build time only)
#   - a C toolchain (clang or gcc)
#   - bison and gperf (mruby regenerates its parser from source)
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
JOBS          ?= 4

MRUBY_STAMP := $(MRUBY_DIR)/.mrb-cr-$(MRUBY_VERSION)
MRUBY_LIB   := $(MRUBY_DIR)/build/$(MRUBY_BUILD)/lib/libmruby.a
LIB_DIR     := lib
DEST_LIB    := $(LIB_DIR)/libmruby.a

.PHONY: all mruby clean distclean check

all: $(DEST_LIB)

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
	cd $(MRUBY_DIR) && MRUBY_CONFIG=$(CURDIR)/build_config/mrb_cr.rb $(RUBY) -S rake -j$(JOBS)

$(DEST_LIB): $(MRUBY_LIB)
	@mkdir -p $(LIB_DIR)
	cp $(MRUBY_LIB) $(DEST_LIB)

check: $(DEST_LIB)
	crystal tool format --check
	crystal spec

clean:
	rm -f $(DEST_LIB)
	rm -rf $(MRUBY_DIR)/build

distclean: clean
	rm -rf $(MRUBY_DIR)
