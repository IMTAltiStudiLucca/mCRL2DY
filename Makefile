M4         ?= m4
M4FLAGS    ?= --prefix-builtins
MCRL22LPS  ?= mcrl22lps
LPS2PBES   ?= lps2pbes
PBES2BOOL  ?= pbes2bool

# Usage:
#   make verify VERBOSE=1
#   make verify LOG_LEVEL=debug
#   make verify-verbose
MCRL2_LOG_FLAGS = $(if $(LOG_LEVEL),--log-level=$(LOG_LEVEL),$(if $(filter 1 yes true,$(VERBOSE)),--verbose,))
MCRL2_TIME_FLAGS = $(if $(filter 1 yes true,$(TIMINGS)),--timings,)
MCRL2_FLAGS = $(MCRL2_LOG_FLAGS) $(MCRL2_TIME_FLAGS)

PROJECT_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
BUILD_DIR   := $(PROJECT_DIR)/build
GOAL_DIR    := $(PROJECT_DIR)/goal
PARTS       := $(PROJECT_DIR)/example/alice_bob.mcrl2 \
               $(PROJECT_DIR)/intruder.mcrl2
MODEL       := $(BUILD_DIR)/dy_model.mcrl2
LPS         := $(BUILD_DIR)/dy_model.lps

PROPERTIES := attack_reachable authentication_violation nonce_leak_reachable
PBES_FILES := $(addprefix $(BUILD_DIR)/,$(addsuffix .pbes,$(PROPERTIES)))

.PHONY: all model build verify verify-all \
        build-verbose verify-verbose verify-all-verbose clean help

all: build

model: $(MODEL)

$(MODEL): $(PARTS)
	@mkdir -p $(BUILD_DIR)
	printf '%s\n' 'm4_changequote([[,]])m4_dnl' \
	  | $(M4) $(M4FLAGS) - $(PARTS) > $@.tmp
	mv $@.tmp $@

build: $(LPS)

$(LPS): $(MODEL)
	$(MCRL22LPS) $(MCRL2_FLAGS) $< $@

$(BUILD_DIR)/%.pbes: $(GOAL_DIR)/%.mcf $(LPS)
	$(LPS2PBES) $(MCRL2_FLAGS) -f $< $(LPS) $@

verify: $(BUILD_DIR)/authentication_violation.pbes
	$(PBES2BOOL) $(MCRL2_FLAGS) $<

verify-all: $(PBES_FILES)
	@set -e; \
	for property in $(PROPERTIES); do \
	  printf '%s: ' "$$property"; \
	  $(PBES2BOOL) $(MCRL2_FLAGS) \
	    "$(BUILD_DIR)/$$property.pbes"; \
	done

# Convenient aliases. Target-specific variables propagate to prerequisites.
build-verbose: VERBOSE=1
build-verbose: build

verify-verbose: VERBOSE=1
verify-verbose: verify

verify-all-verbose: VERBOSE=1
verify-all-verbose: verify-all

clean:
	rm -rf $(BUILD_DIR)

help:
	@printf '%s\n' \
	  'make model                 Assemble the complete mCRL2 model' \
	  'make build                 Generate build/dy_model.lps' \
	  'make verify                Verify authentication_violation.mcf' \
	  'make verify-all            Verify all formulas under goal/' \
	  'make verify VERBOSE=1      Enable short mCRL2 progress logs' \
	  'make verify LOG_LEVEL=debug  Enable detailed mCRL2 logs' \
	  'make verify-verbose        Alias for verbose verification' \
	  'make verify-all-verbose    Verbosely verify every property' \
	  'make build TIMINGS=1       Print timing measurements' \
	  'make clean                 Remove generated files'
