# Part 4: replace whole-graph tsort with incremental plant-when-ready scheduling

## What it does

Sprig used to defer every parsed record until the entire dependency graph had been built
and topologically sorted, then plant everything in that order. `Planter` now schedules
records as they stream in via a new `<<`: a record is built and saved the instant
everything it depends on has already been planted; only records genuinely blocked on
something not-yet-seen are held, indexed by the specific dependency id they're waiting
on. Planting something checks who was waiting on it and wakes them iteratively (a queue,
not recursion). `Planter` only remembers that an id was planted (a string in a hash),
never the record or descriptor itself. This removes `DependencySorter` and
`TsortableHash` entirely; `MissingDependencyError`/`CircularDependencyError` move to
`Sprig::Planter` accordingly.

## How it helps

**This is a correctness fix, not primarily a memory optimization.** The old whole-graph
`TSort`-based sort recurses per node, and a long self-referencing chain declared
newest-first overflows Ruby's stack (`SystemStackError`) at roughly 11,000 records deep.
Verified directly, not just ported as a claim: a 20,000-record self-referencing chain
declared newest-first raises `SystemStackError: stack level too deep` on the pre-scheduler
code and plants all 20,000 records successfully once this change lands. This is a real,
currently-live crash bug on `master` today for anyone seeding a sufficiently long,
badly-ordered self-referencing hierarchy -- independent of any memory number below
(unlikely though it admittedly is.)

The memory mechanism itself is real too: instead of holding the whole graph until
everything is sorted, only descriptors genuinely blocked on something not yet seen are
held at all, and the "planted" bookkeeping is a bare string, not a reference to anything
heavy.

## Empirical evidence

| Tier         |   Peak RSS | vs. part-3 | Storage-space-over-time | vs. part-3 |
| ------------ | ---------: | ---------: | ----------------------: | ---------: |
| Small (1K)   |    93.6 MB |      +1.0% |             168.3 MB\*s |      -0.9% |
| Medium (10K) |   392.4 MB |     +13.4% |           6,630.9 MB\*s |      +2.4% |
| Large (100K) | 2,020.9 MB |      +5.6% |         737,494.4 MB\*s |      -9.7% |

**NOTE: Peak RSS moved in the direction opposite to what the mechanism above predicts**
This dataset's dependency graph is only 2 hops deep (`ProjectTag`/`Task` -> `Project` ->
`Customer`) regardless of N, so it was never going to stress the old whole-graph
scheduler's memory the way a long, badly-ordered single chain does. In other words, this
dataset is not shaped to stress the old scheduler's memory in the way the new scheduler
is designed to avoid.
