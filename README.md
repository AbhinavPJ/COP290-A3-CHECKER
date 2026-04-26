## Setup Instructions

1. From the `leveldb` project root, configure and build a static `libleveldb` (e.g. `cmake -B build -DLEVELDB_BUILD_TESTS=OFF && cmake --build build`).

2. Place this `COP290-A3-CHECKER` folder under `leveldb/`.

3. In `COP290-A3-CHECKER/`, the **Makefile** builds `sample` with `LINK_CXX`, which defaults to `CMAKE_CXX_COMPILER` from `../build/CMakeCache.txt` (so it matches your `libleveldb` ABI). Override if needed: `make COP290_CXX=/path/to/g++` or `make HOST_CXX=clang++`. The environment `CXX` (often `c++` → **clang**) is **not** used, because mixing clang and a g++-built `libleveldb` fails to link.

## Make targets (quick)

| Command | What it does |
|--------|----------------|
| `make` / `make all` | Build `./sample` |
| `make run` | Single-threaded workload; `diff` `out.txt` to `ans.txt` |
| **`make race`** | **Concurrent stress** — `./sample --race-only` (separate DB; no golden; see below) |
| `make test` or `make check` | `make run` then `make race` |
| `make update_golden` | Regenerate `ans.txt` (after intentional trace changes) |
| `make clean` | Remove `sample`, `out.txt` |

## Running the checker

The harness has **two** checks: a **single-threaded** run (output compared to a golden) and a **concurrent** stress (no golden).

1. **Single-threaded** — compiles `sample`, runs it, and compares `out.txt` to `ans.txt` (unified diff on failure):

   ```bash
   cd COP290-A3-CHECKER/
   make
   make run
   ```

2. **Concurrent (race) check** — `make race` runs `./sample --race-only`. Many threads call `Put` / `Get` / `Delete` / `Scan` / `DeleteRange` and interleaved `ForceFullCompaction()` on a **separate** database path (`COP290_RACE_DB` or default `/tmp/testdb_race`), so it does not affect `out.txt`. There is no golden: the process exits **0** if every `Status` is `ok` or `NotFound` (where expected). Tune with `COP290_RACE_THREADS` (default 6) and `COP290_RACE_OPS` (default 2500 per thread).

3. **Both** — `make test` (or `make check`) runs `make run` and then `make race`.

4. **Regenerate `ans.txt`** (after you intentionally change trace format or fix behavior):

   ```bash
   make update_golden
   ```

5. Optional: `./sample --concurrent` runs the full single-threaded workload **then** the same race block in one invocation. `make test` uses `make run` and `make race` separately so the single-threaded path is not executed twice.

6. `sample` begins with a **deterministic** prefix: ReadOptions/snapshot, inverted key range → empty `Scan`, `DeleteRange` on an empty range, and it checks every `Status`. The first line of `out.txt` is `protocol=3 …` (bump if you change that prefix or the log format). The random path uses an in-memory `std::map`; each `Scan` is logged with every `key=>value` in range (not just a size), and after `ForceFullCompaction` every `key1`…`key10000` is checked against the model. Optional: `COP290_DB` for the DB path (default `/tmp/testdb`).
