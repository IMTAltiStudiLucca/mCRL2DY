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

PROPERTIES := attack_reachable
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

verify: $(BUILD_DIR)/attack_reachable.pbes
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

# Attack-trace search configuration
ATTACK_ACTION ?= intruder_wins
ATTACK_MAX_STATES ?= 500000
ATTACK_LPS ?= $(BUILD_DIR)/dy_model.lps
ATTACK_TRACE_GLOB = $(ATTACK_LPS)_act_*_$(ATTACK_ACTION).trc

.PHONY: attack-trace attack-trace-verbose show-attack clean-attack-traces

attack-trace: $(ATTACK_LPS)
	@echo "Searching for action '$(ATTACK_ACTION)'..."
	@rm -f $(ATTACK_TRACE_GLOB)
	lps2lts \
		--cached \
		--strategy=breadth \
		--max=$(ATTACK_MAX_STATES) \
		--action=$(ATTACK_ACTION) \
		--trace=1 \
		$(ATTACK_LPS)
	@set -- $(ATTACK_TRACE_GLOB); \
	if [ ! -e "$$1" ]; then \
		echo "No attack trace found within $(ATTACK_MAX_STATES) states."; \
		exit 1; \
	fi
	@echo "Attack trace generated:"
	@ls -1 $(ATTACK_TRACE_GLOB)

attack-trace-verbose: $(ATTACK_LPS)
	@$(MAKE) attack-trace \
		ATTACK_ACTION="$(ATTACK_ACTION)" \
		ATTACK_MAX_STATES="$(ATTACK_MAX_STATES)" \
		LPS2LTS_VERBOSE=1

show-attack:
	@set -- $(ATTACK_TRACE_GLOB); \
	if [ ! -e "$$1" ]; then \
		echo "No trace found. Run 'make attack-trace' first."; \
		exit 1; \
	fi; \
	tracepp --format=plain "$$1"

clean-attack-traces:
	rm -f $(ATTACK_TRACE_GLOB)

help:
	@echo "mCRL2DY — available targets"
	@echo ""
	@echo "Model construction:"
	@echo "  make model                  Generate the combined mCRL2 model"
	@echo "  make build                  Generate and linearise the model"
	@echo "  make build-verbose          Build with verbose mCRL2 output"
	@echo ""
	@echo "Property verification:"
	@echo "  make verify                 Verify the default property"
	@echo "  make verify-all             Verify all properties in goal/"
	@echo "  make verify-verbose         Verify with verbose output"
	@echo ""
	@echo "Attack-trace search:"
	@echo "  make attack-trace           Find a trace leading to intruder_wins"
	@echo "  make attack-trace-verbose   Find an attack trace with verbose output"
	@echo "  make show-attack            Print the generated trace in plain format"
	@echo "  make clean-attack-traces    Remove generated attack traces"
	@echo ""
	@echo "Cleaning:"
	@echo "  make clean                  Remove all generated build artifacts"
	@echo ""
	@echo "Optional parameters:"
	@echo "  ATTACK_ACTION=<action>      Action searched by lps2lts"
	@echo "                              Default: intruder_wins"
	@echo "  ATTACK_MAX_STATES=<number>  Maximum number of explored states"
	@echo "                              Default: 500000"
	@echo ""
	@echo "Examples:"
	@echo "  make build-verbose"
	@echo "  make attack-trace"
	@echo "  make attack-trace-verbose ATTACK_MAX_STATES=1000000"
	@echo "  make attack-trace ATTACK_ACTION=bob_commit"
	@echo "  make show-attack"
