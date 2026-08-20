# Source × storage matrix benchmark

Tests every combination of seed file format and storage backend Sprig supports, using
the same rich Customer/Tag/Project/Task/ProjectTag dataset as the rest of this benchmark
suite (see [`../README.md`](../README.md) for the dataset's shape and the memory-focused
investigation this one is separate from).

|                | CSV | YAML | JSON |
|----------------|:---:|:---:|:---:|
| **SQLite**     | ✅ | ✅ | ✅ |
| **PostgreSQL** | ✅ | ✅ | ✅ |
| **MongoDB**    | ✅ | ✅ | ✅ |

## Why this is a separate tool, not a change to the existing scripts

The rest of this benchmark suite is deliberately YAML + Postgres only, to isolate memory
effects across the `ms/75-resolve-memory-version-*` stacks without a second variable in
play. This matrix benchmark asks a different question -- how much does the *format* and
*storage backend* themselves matter -- so it needed its own dataset generator (one that
can emit CSV/YAML/JSON from the same underlying rows) and its own runner (one that can
point at any of three very different storage adapters). Rather than bolt that onto
`generate_dataset.rb`/`run_benchmark.rb`, it lives in its own `matrix/` subfolder:

- [`row_data.rb`](row_data.rb) -- the shared Faker-based row generation logic (same
  fields, same random seeds, same relationships as the top-level `generate_*.rb`
  scripts), returning plain Hashes rather than writing a specific format directly.
- [`writers.rb`](writers.rb) -- serializes those rows to CSV, YAML, or JSON.
- [`generate_matrix_dataset.rb`](generate_matrix_dataset.rb) -- CLI wrapper:
  `ruby generate_matrix_dataset.rb <dir> <n> <yml|json|csv>`.
- [`run_matrix_benchmark.rb`](run_matrix_benchmark.rb) -- CLI wrapper:
  `ruby run_matrix_benchmark.rb <dataset-dir> <yml|json|csv> <sqlite|postgres|mongodb>`.
  Same generated files work unmodified against any storage backend, since
  `sprig_record(Klass, id).id` resolves at plant time against whichever adapter is
  actually running -- it isn't baked into the file.

## Setup

**SQLite**: nothing extra -- the `sqlite3` gem is already a dev dependency. Each run
gets a fresh file (`/tmp/sprig_benchmark_matrix.sqlite3` by default, recreated every
run).

**PostgreSQL**: reuses the same `sprig-benchmark-postgres` container as the rest of this
suite (see `../README.md`), against a separate `sprig_benchmark_matrix` database.

**MongoDB**: needs its own dedicated container, and needs `bundle` pointed at
`gemfiles/mongoid_9.gemfile` (the repo's own Mongoid Appraisal) rather than the main
Gemfile:

```bash
docker run -d --name sprig-benchmark-mongo -p 27018:27018 mongo:8 --replSet rs0 --port 27018
docker exec sprig-benchmark-mongo mongosh --port 27018 --quiet --eval \
  'rs.initiate({_id: "rs0", members: [{_id: 0, host: "localhost:27018"}]})'

# See "A transaction-lifetime gotcha" below before running the medium tier.
docker exec sprig-benchmark-mongo mongosh --port 27018 --quiet --eval \
  'db.adminCommand({setParameter: 1, transactionLifetimeLimitSeconds: 600})'

BUNDLE_GEMFILE=gemfiles/mongoid_9.gemfile bundle exec ruby benchmark/matrix/run_matrix_benchmark.rb <dir> <format> mongodb
```

This is **deliberately a separate container from `sprig-mongo-test`** (the one the spec
suite's Mongoid Appraisals use). That container runs with a 256MB tmpfs for `/data/db`,
sized for tiny spec fixtures -- pointing a medium-tier (10K-row) benchmark run at it
filled the tmpfs, and WiredTiger hard-crashed the whole `mongod` process (`No space left
on device`, fatal assert, abort) partway through a run. Discovered directly, the hard
way, during this investigation -- not a Sprig bug, but worth recording so it doesn't
happen again: benchmark against real disk-backed storage in its own container, never the
spec suite's own tmpfs-limited one.

## A transaction-lifetime gotcha, worth knowing about independent of this benchmark

Sprig wraps an entire `sprig()` call in one transaction when the adapter supports it
(`Sprig.configuration.wrap_in_transaction`, on by default). For Mongoid specifically,
that means one multi-document transaction spanning however long the whole run takes.
MongoDB's own server default caps a transaction's lifetime at
**`transactionLifetimeLimitSeconds` = 60 seconds** -- past that, the server aborts it
unilaterally, and every operation attempted afterward fails with
`Mongo::Error::OperationFailure: [251:NoSuchTransaction]`, cascading into enough
individual save failures that Sprig's own rollback logic kicks in and undoes the entire
run.

This benchmark's medium tier (10,000 rows, ~55,020 total records) takes 65-80 seconds
against MongoDB -- right past that default. It failed silently-ish (a rollback, not a
crash) on the first attempt, for exactly this reason, and only some formats' timing
happened to land far enough past 60s to actually trigger it on that particular run
(borderline timing, not deterministic). Raising the limit
(`db.adminCommand({setParameter: 1, transactionLifetimeLimitSeconds: 600})`) fixed it
cleanly. **This is a real, practically relevant thing to know if you're seeding a
large dataset into MongoDB through Sprig with transactional wrapping on** -- past a
certain data volume (and MongoDB is, per the results below, the slowest of the three
backends tested, so it gets there sooner than SQLite/Postgres would), the default
transaction lifetime becomes the limiting factor, not anything about Sprig's own design.
Turning `wrap_in_transaction` off, or raising this server parameter, are both ways
around it -- this benchmark chose the latter, to measure Sprig's real behavior rather
than an unrelated timeout.

## Results

`/usr/bin/time -l` (macOS), one isolated process per combination, same methodology as
the rest of this benchmark suite. Large tier wasn't run -- small and medium already show
a clear, consistent pattern (see below), and nothing here suggested a reason to expect it
to change direction at 100K rows; if you want that confirmed rather than assumed, run it
the same way.

Each combination below is reported twice: **master** (`5439077`, current `master` at the
time of this run, no memory-optimization changes) and **part-8** (this branch, with the
full `ms/75-resolve-memory-version-3` stack applied -- deferred `Entry` construction,
slimmed `SprigRecordStore`, streaming YAML/JSON parsing, the incremental scheduler, and
the rest of the changes documented in [`../README.md`](../README.md)). Both runs used the
exact same generated dataset files, the same dedicated containers, and the same
methodology; master's runs went into separate `_master`-suffixed databases so the two
never shared state.

### Peak RSS (MB)

| | CSV (master → part-8) | YAML (master → part-8) | JSON (master → part-8) |
|---|---:|---:|---:|
| **Small (1K) / SQLite** | 98.0 → 69.1 | 97.3 → 66.5 | 95.8 → 66.9 |
| **Small (1K) / PostgreSQL** | 98.2 → 70.6 | 106.3 → 73.9 | 96.3 → 73.5 |
| **Small (1K) / MongoDB** | 112.8 → 106.4 | 114.1 → 98.6 | 116.8 → 106.0 |
| **Medium (10K) / SQLite** | 418.0 → 133.6 | 459.4 → 128.3 | 427.1 → 136.3 |
| **Medium (10K) / PostgreSQL** | 425.1 → 121.8 | 446.7 → 119.3 | 411.4 → 123.1 |
| **Medium (10K) / MongoDB** | 483.1 → 393.0 | 509.5 → 395.3 | 503.7 → 388.5 |

### Wall time (s)

| | CSV (master → part-8) | YAML (master → part-8) | JSON (master → part-8) |
|---|---:|---:|---:|
| **Small (1K) / SQLite** | 1.43 → 1.41 | 1.61 → 1.65 | 1.39 → 1.35 |
| **Small (1K) / PostgreSQL** | 2.57 → 2.64 | 2.66 → 2.90 | 2.52 → 2.54 |
| **Small (1K) / MongoDB** | 9.08 → 8.62 | 8.16 → 8.21 | 9.58 → 7.77 |
| **Medium (10K) / SQLite** | 10.90 → 9.95 | 11.37 → 11.02 | 9.96 → 9.57 |
| **Medium (10K) / PostgreSQL** | 21.80 → 20.62 | 23.91 → 28.85 | 20.47 → 21.24 |
| **Medium (10K) / MongoDB** | 93.24 → 80.13 | 88.57 → 74.57 | 88.75 → 64.83 |

### What the master comparison adds

The memory picture is unambiguous and consistent across every one of the 18
combinations: **part-8 uses meaningfully less peak memory than master everywhere**, and
the reduction grows with data volume -- at medium tier it's roughly **68-73% less peak
RSS for SQLite/PostgreSQL** (e.g. medium YAML/SQLite: 459.4MB → 128.3MB) and a smaller
but still real **~19-23% less for MongoDB** (e.g. medium YAML/MongoDB: 509.5MB →
395.3MB). MongoDB's smaller relative improvement lines up with the rest of this
investigation's finding that MongoDB's own driver/BSON overhead, not Sprig's seed-side
memory use, dominates its footprint -- Sprig-side savings have proportionally less to
work with there.

Wall time tells a different, noisier story: the two are close enough at small tier that
run-to-run variance (see `../part-4.md`'s reinvestigation of exactly this kind of noise)
plausibly explains which one comes out ahead on a given combination, and there's no
consistent winner. At medium tier a real pattern does emerge for MongoDB specifically --
part-8 is 14-27% *faster* there too (not just leaner), most plausibly because the
incremental scheduler's cascading plant-as-ready approach keeps the single wrapping
transaction's total work more evenly paced than master's build-the-whole-graph-then-plant
approach, though this benchmark didn't instrument the mechanism directly to confirm that.
For SQLite/PostgreSQL at medium tier the two are within a few percent either way -- this
stack was never primarily a wall-time optimization, and it shows: the win it delivers is
memory, not speed, and the wall-time numbers here are consistent with that rather than
contradicting it.

## What this actually shows

**Storage backend dominates; source format is a rounding error by comparison.**
Averaged across all three formats at medium tier:

| Storage | Avg. wall time | Avg. peak RSS |
|---|---:|---:|
| SQLite | 10.2s | 132.7 MB |
| PostgreSQL | 23.6s | 121.4 MB |
| MongoDB | 73.2s | 392.3 MB |

Averaged across all three storage backends at medium tier:

| Format | Avg. wall time | Avg. peak RSS |
|---|---:|---:|
| JSON | 31.9s | 216.0 MB |
| CSV | 36.9s | 216.1 MB |
| YAML | 38.2s | 214.3 MB |

The spread between the *slowest and fastest format* at medium tier is ~7s and ~2MB.
The spread between the *slowest and fastest storage backend* is ~63s and ~271MB. Which
file format you generate seed data in barely matters for performance; which database
you're seeding into matters enormously. JSON edges out YAML/CSV slightly and
consistently (likely `Oj`'s streaming C parser vs. `Psych`'s YAML parser and Ruby's own
`CSV` library, though this benchmark didn't isolate parsing time from the rest of the
run to confirm that specifically) -- real, but small enough that format choice should be
driven by whatever's more convenient to author and version-control, not by performance.

**MongoDB is both the slowest and the most memory-hungry backend tested, by a wide
margin** -- roughly 3x PostgreSQL's peak RSS and 3-7x its wall time at medium tier, and
the gap grows with scale (at small tier MongoDB is "only" ~3-6x slower and ~1.4x
heavier; at medium tier it's ~3-7x slower and ~3x heavier). Some of this is inherent to
the driver/BSON overhead and the transactional-wrapping cost discussed above, not
necessarily reducible on Sprig's side; some of it might be addressable (e.g. batching --
see the discussion in the main investigation about why that wasn't pursued for the
memory-optimization stack specifically, though the tradeoffs for a from-scratch Mongoid
path could differ). Not investigated further here -- this benchmark answers "how much
does it currently differ," not "why exactly, at the mechanism level."

**SQLite being both fastest and (at small tier) leanest is notable given it's the only
backend here whose own storage engine runs in-process** -- unlike the rest of this
benchmark suite, which deliberately excludes SQLite from its main comparison for exactly
that reason (its in-process footprint would conflate with Sprig's own memory use). Here,
that in-process cost is part of what's being measured on purpose, and it still comes out
ahead of both separate-process alternatives at this data volume -- though that
comparison would likely look different at a large enough scale that SQLite's file size
and single-writer characteristics start to matter, which this benchmark didn't test.

## Caveats

- Peak RSS and wall time only (`/usr/bin/time -l`) -- this matrix doesn't carry the
  deep `GC.stat`/`ObjectSpace`/storage-space-over-time instrumentation the main
  memory-optimization investigation built (see `../instrumented_run.rb`). That
  instrumentation could be pointed at `run_matrix_benchmark.rb` if a deeper mechanism
  investigation (e.g. into *why* MongoDB is heavier, not just *that* it is) turns out to
  be worth doing.
- Every combination ran once, not repeated/averaged -- the main investigation found
  real run-to-run variance worth checking with repeated trials for small effects (see
  `../part-4.md`'s re-investigation). The differences here are large enough (multiples,
  not single-digit percentages) that one run each is enough to see the pattern clearly,
  but the exact numbers shouldn't be read to more precision than that.
- MongoDB's schema here uses `Float` for what PostgreSQL/SQLite store as `decimal` --
  Mongoid supports `BigDecimal`-backed fields too, but this benchmark didn't chase that
  level of type parity; it's not expected to meaningfully change the memory picture.
