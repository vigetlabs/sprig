# Part 2: introduce `Seed::Descriptor`; defer `Entry` materialization to plant time

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
Since every record still waiting to plant sits in memory as _something_ until its
dependencies resolve, the cost of "something" matters directly: swapping the retained
object from `Entry` to `Descriptor` doesn't change _how many_ records wait or _how long_,
only _how much each one costs while it does_.

## Empirical evidence

| Tier         |   Peak RSS | vs. part-1 | Storage-space-over-time | vs. part-1 |
| ------------ | ---------: | ---------: | ----------------------: | ---------: |
| Small (1K)   |    93.3 MB |      -9.0% |             171.5 MB\*s |      -7.9% |
| Medium (10K) |   370.4 MB |     -10.1% |           6,809.0 MB\*s |     -11.7% |
| Large (100K) | 2,168.3 MB |     -23.0% |         896,868.3 MB\*s |      -1.6% |

Per-item retained-structure cost, measured directly via `ObjectSpace` (medium tier, final
snapshot): a `Descriptor` costs ~1,552 bytes, versus a fully-built `Entry`'s ~7,168 bytes
at part-1 -- roughly 22% of an `Entry`'s footprint, a larger reduction than the ~40%-less
figure cited in this codebase's own earlier process documentation for an equivalent-sized
row.
