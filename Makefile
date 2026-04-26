# COP290 A3 — local regression harness (not the official TA grader).
# Build parent LevelDB first, e.g. from repo root:
#   cmake -B build -DCMAKE_BUILD_TYPE=Release
#   cmake --build build -j
#
# The sample must use the *same* C++ ABI as libleveldb. By default this Makefile
# sets LINK_CXX from $(BUILD_DIR)/CMakeCache.txt (CMAKE_CXX_COMPILER). Override with
#   make COP290_CXX=/path/to/g++-15   or   make HOST_CXX=clang++

BUILD_DIR         ?= ../build
LEVELDB_LIB_DIR   ?= $(BUILD_DIR)
LEVELDB_INCLUDE   ?= ../include
SAMPLE            ?= sample

CMAKE_CXX  := $(shell f="$(BUILD_DIR)/CMakeCache.txt"; test -f "$$f" && sed -n 's/^CMAKE_CXX_COMPILER:[A-Z]*=//p' "$$f" | head -1)
COP290_CXX ?=
HOST_CXX   ?=
# Never use the implicit environment CXX (c++/clang vs g++ ABI). Priority:
# COP290_CXX, then HOST_CXX, then CMAKE_CXX from cache, else g++.
ifeq ($(strip $(COP290_CXX)),)
  ifeq ($(strip $(HOST_CXX)),)
    LINK_CXX := $(or $(strip $(CMAKE_CXX)),g++)
  else
    LINK_CXX := $(HOST_CXX)
  endif
else
  LINK_CXX := $(COP290_CXX)
endif

CXXFLAGS += -std=c++17 -fno-exceptions -fno-rtti
CXXFLAGS += -I$(LEVELDB_INCLUDE)
# Generated headers (e.g. port_config.h) from the CMake build tree
CXXFLAGS += -I$(BUILD_DIR)/include
LDFLAGS  += -L$(LEVELDB_LIB_DIR) -lleveldb -lpthread

.PHONY: all clean run strong strong_run race test check update_golden help

all: $(SAMPLE)

$(SAMPLE): sample.cpp
	$(LINK_CXX) $(CXXFLAGS) sample.cpp -o $(SAMPLE) $(LDFLAGS)

help:
	@echo "Targets: all, run, strong (strong_run), test (check), update_golden, clean"
	@echo "  COP290_DB=path  — DB directory (default /tmp/testdb, cleared before run)"
	@echo "  COP290_CXX=path  — C++ compiler (highest priority; must match libleveldb build)"
	@echo "  HOST_CXX=path  — if COP290_CXX unset, used to link the sample (default: from CMakeCache)"
	@echo "  BUILD_DIR=path  — CMake build directory (default ../build)"
	@echo "  COP290_RACE_DB, COP290_RACE_THREADS, COP290_RACE_OPS — see README (concurrent / race target)"
	@echo "./sample         — writes out.txt, exits 0 if no API/IO error (compare with make run)"
	@echo "./sample --write — writes ans.txt; use once for update_golden"
	@echo "make race        — ./sample --race-only (multi-threaded stress; no golden; pass/fail)"
	@echo "make test        — run, strong, then race (clarification-style concurrency check)"

clean:
	rm -f out.txt compaction_stats.txt $(SAMPLE) sample.o

# Basic: deterministic + random workload, compare Get/Scan trace to ans.txt
run: $(SAMPLE) ans.txt
	rm -f out.txt compaction_stats.txt
	@if [ -n "$$COP290_DB" ]; then rm -rf "$$COP290_DB"; else rm -rf /tmp/testdb; fi
	./$(SAMPLE)
	@if diff -u ans.txt out.txt; then \
	  echo "OK: out.txt matches ans.txt"; \
	else \
	  echo "FAIL: out.txt differs from ans.txt (unified diff above)."; \
	  exit 1; \
	fi

# Strong: require each line to have 5 numeric fields (assignment may still log
# bytes), then compare only the first 3 (compactions, input files, output files)
# to compaction_portable_ans.txt — byte totals are not portable across runs/OSes.
strong: run compaction_portable_ans.txt
	@sh verify_compaction_stats.sh compaction_stats.txt
	@lines_a=$$(wc -l < compaction_stats.txt | tr -d ' '); \
	lines_b=$$(wc -l < compaction_portable_ans.txt | tr -d ' '); \
	if [ "$$lines_a" -ne "$$lines_b" ]; then \
	  echo "FAIL: line count: compaction_stats.txt ($$lines_a) vs compaction_portable_ans.txt ($$lines_b)"; \
	  exit 1; \
	fi
	@sh diff_compaction_portable.sh compaction_stats.txt compaction_portable_ans.txt

strong_run: strong

# Concurrent / race stress (separate DB path, no out.txt, no ans compare).
# Integrates with LevelDB's thread-safe API: Put / Get / Delete / Scan /
# DeleteRange from many threads, plus interleaved ForceFullCompaction.
race: $(SAMPLE)
	@if [ -n "$$COP290_RACE_DB" ]; then rm -rf "$$COP290_RACE_DB"; else rm -rf /tmp/testdb_race; fi
	./$(SAMPLE) --race-only

# Full local checker: deterministic + portable compaction + concurrent stress
test: strong race
check: test

# Rebuild reference outputs. One --write run; portable golden = first 3 fields only.
update_golden: $(SAMPLE)
	@echo "Overwrites ans.txt and compaction_portable_ans.txt. Build reference LevelDB first."
	rm -f out.txt ans.txt compaction_stats.txt compaction_portable_ans.txt
	@if [ -z "$$COP290_DB" ]; then rm -rf /tmp/testdb; else rm -rf "$$COP290_DB"; fi
	./$(SAMPLE) --write
	@if [ -z "$$COP290_DB" ]; then : ; else \
	  echo "Using COP290_DB=$$COP290_DB for this golden — keep the same for make run."; \
	fi
	@awk -F'; ' 'NF >= 5 { print $$1 "; " $$2 "; " $$3 }' compaction_stats.txt > compaction_portable_ans.txt
	@echo "Wrote fresh ans.txt and compaction_portable_ans.txt (structural only; bytes not golden-stored)"
