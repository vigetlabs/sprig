# Part 1: benchmark harness

## What it does

No `lib/` changes. Adds the measurement tooling every later part in this stack is
benchmarked against:

- A consolidated, always-adversarial dataset -- `Customer`/`Tag` (independent) +
  `Project` (optionally belongs to `Customer`) + `Task` (always belongs to `Project`) +
  `ProjectTag` (always belongs to both a `Project` _and_ a `Tag` -- a genuine
  many-to-many, and the only model here that depends on two independent things at once)
  -- replacing four scattered scenario variants from the original, pre-`master`-rebase
  investigation with one richer scenario, at N = 1,000 / 10,000 / 100,000
  (small/medium/large).
- Every directive declared and offered dependency-last (`ProjectTag, Task, Project, Tag,
Customer`) -- the hardest case, not an opt-in flag.
- A real, separate PostgreSQL server via Docker, not in-process SQLite, from the start.
- `benchmark/instrumented_run.rb`/`benchmark/analyze_traces.rb`, a diagnostic harness
  (not part of the library) that polls RSS/`GC.stat` throughout a run, computes the
  storage-space-over-time (memory-time) integral, and takes a one-time post-run
  `ObjectSpace` breakdown of the specific structures this investigation cares about.

## How it helps

It's the foundation everything else in this stack is measured against, and its two
design choices both matter for getting a trustworthy measurement:

- **Always dependency-last ordering** is the scenario that actually distinguishes a
  scheduler that holds the whole dataset in memory from one that doesn't -- a
  well-ordered dataset wouldn't exercise the difference parts 4/5 are about.
- **A real, separate Postgres server** avoids SQLite's own in-process storage (B-tree
  pages, buffers) running inside the same OS process being measured -- the original
  investigation found this could make an isolated pure-storage measurement look _larger_
  than the entire real pipeline that included it, which isn't possible if SQLite's
  contribution were a genuinely fixed, external cost.

## Empirical evidence

No memory numbers of its own -- it's the baseline every later part's percentage is
measured against. Its own peak RSS and storage-space-over-time figures anchor the
`benchmark/README.md` tables:

| Tier                       |   Peak RSS | Storage-space-over-time |
| -------------------------- | ---------: | ----------------------: |
| Small (1K, 5,520 rows)     |   102.5 MB |             186.2 MB\*s |
| Medium (10K, 55,020 rows)  |   411.9 MB |           7,712.5 MB\*s |
| Large (100K, 550,020 rows) | 2,817.4 MB |         911,672.1 MB\*s |
