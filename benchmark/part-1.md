# Part 1: benchmark harness

## What it does

No `lib/` changes. Adds the measurement tooling every later part in this stack is
benchmarked against:

- A consolidated, always-adversarial dataset -- `Customer`/`Tag` (independent) +
  `Project` (optionally belongs to `Customer`) + `Task` (always belongs to `Project`) +
  `ProjectTag` (always belongs to both a `Project` *and* a `Tag` -- a genuine
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
  investigation found this could make an isolated pure-storage measurement look *larger*
  than the entire real pipeline that included it, which isn't possible if SQLite's
  contribution were a genuinely fixed, external cost.

## Empirical evidence

No memory numbers of its own -- it's the baseline every later part's percentage is
measured against. Its own peak RSS and storage-space-over-time figures anchor the
`benchmark/README.md` tables:

| Tier | Peak RSS | Storage-space-over-time |
|---|---:|---:|
| Small (1K, 5,520 rows) | 102.5 MB | 186.2 MB\*s |
| Medium (10K, 55,020 rows) | 411.9 MB | 7,712.5 MB\*s |
| Large (100K, 550,020 rows) | 2,817.4 MB | 911,672.1 MB\*s |

## Additional notes

**A real, previously-undiscovered bug in this part's own generator scripts was found and
fixed during this investigation, after this stack was first built.** The generators
originally wrote foreign keys as `sprig_record(Customer, N)` -- assigning the entire
fetched `Customer` object directly to the `customer_id` column, not its id.
`ActiveRecord`'s integer type-cast doesn't raise on a value that doesn't respond to
`#to_i`; it silently casts to `nil`. Checked directly against the live benchmark database
before fixing this: every foreign key in every table (`projects.customer_id`,
`tasks.project_id`, `project_tags.project_id`/`tag_id`) was `NULL`, in every run across
both the version-2 and (until this fix) version-3 stacks -- this benchmark never actually
exercised realistic seed data until this fix landed. Fixed by writing
`sprig_record(Customer, N).id` instead, amended directly into this commit (not a
follow-up fix), since that's where the generators live; every later part in this stack
was rebuilt on top of the correction. Verified after the fix, directly against the live
database: ~70% of `projects` carry a real `customer_id` matching an actual `customers.id`
(matching the generator's own intended `link_probability`), the rest are genuinely,
intentionally `NULL` (by design, not by bug), and all `project_tags` rows resolve both
their `project_id` and `tag_id`.

This bug never invalidated any memory or performance number measured against it:
dependency detection runs on the raw seed-file text via regex, before any `eval`, so the
scheduler's wait/cascade logic and the count of `sprig_record(...)` evaluations were
completely unaffected by what the fetched value was subsequently used for. But fixing it
did change the numbers reported for every later part in this stack, in one specific way:
it exposed that `SprigRecordStore#get` was paying a full database round trip for every
`sprig_record(...)` reference even though this dataset's actual usage never needed more
than the id -- see part 5's writeup for what that led to.

See [`benchmark/README.md`](README.md) for the full stack-wide results and the "Why the
reorder changes the story" section for the complete account of both bugs found during
this investigation.
