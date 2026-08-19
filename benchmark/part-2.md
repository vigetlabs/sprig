# Part 2: introduce `Seed::Descriptor`; defer `Entry` materialization to plant time

Port of the original, pre-`master`-rebase investigation's Option B (`6df0cad`) onto
current `master`.

## What it does

`Factory#add_seeds_to_hopper` used to turn every parsed row into a full `Seed::Entry` up
front -- attributes wrapped, values pre-processed -- before dependency order was even
known, so the whole hopper held heavy objects for every table for the entire sort+plant
run. `Factory` now pushes a lightweight `Descriptor` instead (raw row + class + options);
`Planter#plant` calls `descriptor.to_entry` to build the real `Entry` only at the instant
a record is about to be saved. `Entry#initialize` gained an optional `sprig_id` argument
so the id the descriptor already computed carries through instead of re-rolling a second
one.

## How it helps

A `Descriptor` is intentionally cheap: just the class, the raw row data, and the options
-- nothing wrapped, nothing type-cast. An `Entry`, by contrast, wraps every field in its
own `Attribute` (type-cast/dirty-tracking machinery), which costs real memory per field.
Since every record still waiting to plant sits in memory as *something* until its
dependencies resolve, the cost of "something" matters directly: swapping the retained
object from `Entry` to `Descriptor` doesn't change *how many* records wait or *how long*,
only *how much each one costs while it does*.

## Empirical evidence

| Tier | Peak RSS | vs. part-1 | Storage-space-over-time | vs. part-1 |
|---|---:|---:|---:|---:|
| Small (1K) | 93.3 MB | -9.0% | 171.5 MB\*s | -7.9% |
| Medium (10K) | 370.4 MB | -10.1% | 6,809.0 MB\*s | -11.7% |
| Large (100K) | 2,168.3 MB | -23.0% | 896,868.3 MB\*s | -1.6% |

Per-item retained-structure cost, measured directly via `ObjectSpace` (medium tier, final
snapshot): a `Descriptor` costs ~1,552 bytes, versus a fully-built `Entry`'s ~7,168 bytes
at part-1 -- roughly 22% of an `Entry`'s footprint, a larger reduction than the ~40%-less
figure cited in this codebase's own earlier process documentation for an equivalent-sized
row.

## Additional notes

Beyond the port itself, this stage needed integration work caused by `master` having
moved on since the original investigation branched:

- `Descriptor`'s dependency-detection now reuses `Attribute`'s own
  `SPRIG_RECORD_REFERENCE`/`ID_LITERAL` constants (added to `master` after the original
  stack branched) instead of a second, hand-copied numeric-only regex -- the original
  port's copy predates that fix and would have silently regressed quoted/symbol
  `sprig_id`s for any seed file using them in a cross-reference.
- `Descriptor` gained a public `klass` reader (the original made it private). `master`'s
  transactional `Planter` reads `dependency_sorted_seeds.first.klass` to pick a Mongoid
  transaction anchor -- caught by running the ported `planter_spec.rb` against the
  mongoid-9 Appraisal, not just the default ActiveRecord suite.
- The ported `planter_spec.rb`'s doubles needed `errors?: false` and `klass: Post` added,
  since `master`'s `Planter#sprig` now always calls `notifier.errors?` (for the
  transaction-rollback check) and the Mongoid anchor-class path reads `.klass` off the
  first seed -- neither existed when this spec was originally written against the old,
  pre-transactional `Planter`.

Full spec suite (168 examples) passed on the default (ActiveRecord) config, the
rails-8.1 Appraisal, and the mongoid-9 Appraisal at the time this stage was ported;
standardrb clean on every changed file.
