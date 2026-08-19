# Part 5: stop retaining full records in `SprigRecordStore`; re-fetch lazily by id

Moved from version-2's `part-2` (where it ran right after the harness, before the
scheduler) to run here instead, after part 4's incremental scheduler -- with a further
refinement, the lazy id-only path described below, folded into the same commit.

## What it does

`sprig_id` is a seed-file-only identifier -- `Entry#initialize` deletes it from a
record's attributes before it's ever saved, so it never becomes a real column, and
there's no way to look a record back up by `sprig_id` via the database directly.
`SprigRecordStore#save` used to keep the actual saved record object alive for the rest of
the run, keyed by class + `sprig_id`, purely so a later `sprig_record(Klass, id)`
reference could look it up. `#save` now stores just `record.id`.

`#get` returns a `Sprig::SprigRecordStore::LazyRecord` rather than either the old
in-memory object or an eagerly re-fetched one. `LazyRecord` already knows the id (that's
all the store ever held) and answers `#id` directly with zero database access; any other
method call -- an attribute, an association, anything beyond the id -- falls through to a
real `klass.find(id)`, fetched at most once and memoized, then delegated to.

## How it helps

A live `ActiveRecord`/Mongoid instance is far heavier than the row it represents -- every
column becomes its own type-cast/dirty-tracking wrapper object. Holding every planted
record forever, purely so a handful of later references *might* look it up, is a cost
that grows with the whole dataset regardless of how many records are actually referenced
again. Re-fetching by id instead means only the id (a bare string-keyed hash entry) is
retained.

That alone would still cost a database round trip on every `sprig_record(...)`
evaluation, whether or not the caller needed anything beyond the id. `sprig_record(Klass,
id)` is overwhelmingly used just to read the id back off for a foreign key
(`sprig_record(Klass, id).id`) -- exactly the case `LazyRecord` never has to touch the
database for. Usages that need more than the id still pay for exactly one real fetch,
same as an eager re-fetch would have.

## Empirical evidence

| Tier | Peak RSS | vs. part-4 | Storage-space-over-time | vs. part-4 |
|---|---:|---:|---:|---:|
| Small (1K) | 79.8 MB | -14.7% | 156.8 MB\*s | -6.8% |
| Medium (10K) | 228.2 MB | **-41.8%** | 4,787.5 MB\*s | **-27.8%** |
| Large (100K) | 1,232.0 MB | **-39.0%** | 306,955.2 MB\*s | **-58.4%** |

Wall time, part-5 vs. part-4: small 2.019s -> 2.024s (flat); medium 23.47s -> 21.96s
(**-6.4%**); large 1,143.1s -> 458.5s, a **-59.9% improvement, not a cost** -- the
wall-time win grows sharply with scale, the mirror image of how version-2's wall-time
*regression* for this same idea also grew with scale.

### Why this looks completely different from version-2's measurement of the same idea

Version-2 measured this exact change (right after the harness, before the scheduler) as
a regression that worsened with scale: +4%/+12%/+29% peak RSS and +56%/+77%/+79% wall
time, small/medium/large. Measured here, after the scheduler, the same underlying idea is
a substantial win instead. Two separate things account for the full gap between those two
results:

1. **Position in the stack (the reorder itself).** Under the old whole-graph pipeline
   (parts 1-3 in this stack), every record and every reference to it stays alive for the
   entire run regardless of what `SprigRecordStore` does -- the old `Planter`'s
   `dependency_sorted_seeds` array is memoized and iterated with `#each`, and
   `Sprig::Seed::Attribute#value` memoizes the raw result of evaluating
   `<%= sprig_record(Klass, id) %>` for the life of that record's `Entry`. Under
   hold-forever, every reference to the same id resolves to the *same* shared object, so
   this costs nothing extra; under re-fetch-by-id, each reference used to construct and
   permanently pin its own distinct object. That's why re-fetch regressed specifically on
   the old pipeline, and specifically worse the more cross-references a dataset has --
   this dataset's `ProjectTag` join is exactly that shape. Under the scheduler (part 4
   onward), nothing is memoized past the point it's needed, so that permanent-pinning
   effect doesn't happen in the first place. An earlier pass of this investigation
   measured the reorder's effect alone (before the fixes below existed): -22.2%/-33.7%
   peak RSS at small/medium versus part 4, a real win already.
2. **The lazy id-only path (this commit's own refinement, on top of the reorder).**
   Fixing part 1's `NULL`-foreign-key bug (see part 1's writeup) exposed that
   `SprigRecordStore#get` was still doing a full `klass.find(id)` for every single
   evaluation, immediately discarding everything except the id -- a real, fixable cost
   that a plain eager re-fetch design still pays even after the reorder. Adding the
   `LazyRecord` proxy described above eliminates nearly all of the actual database round
   trips this investigation was originally built around measuring, since this dataset's
   usage of `sprig_record(...)` is entirely `.id`-only.

Combined, these two changes move the small/medium numbers from -22.2%/-33.7% (reorder
alone, on the still-buggy dataset) to -14.7%/-41.8% (reorder plus lazy fetch, correct
dataset) versus part 4 -- **not a smaller effect than initially measured, a larger one**,
which was flagged as a real risk before this refinement was built: removing the round
trip's wall-time/GC cost was expected to shrink the interesting story, and instead made
the underlying "stop holding records forever" benefit show through more clearly. Wall
time confirms the mechanism directly: this stack's own pre-fix pass measured re-fetch (at
this position in the stack) costing +49%/+59%/+160% wall time versus part 4
(small/medium/large); with the round trip mostly eliminated, it's now flat to slightly
*faster*.

`SprigRecordStore`'s own retained content is confirmed genuinely near-zero either way:
`store_per_item_bytes` measures 0 for this design in every run, whether or not the lazy
path is in play -- the difference between the two measurements above is entirely about
what stays reachable *elsewhere*, not about what this store itself holds.

## Additional notes

The conclusion from all of this isn't "reorder version-2's actual stack" -- that stack is
left as-is, and a separate, earlier check of literally reordering within that single
stack found it would obscure other stages' own isolated contributions behind an unrelated
hold-forever memory tax for several stages, for no real gain (the final, all-parts-
combined codebase is identical either way, since this change touches only
`lib/sprig/sprig_record_store.rb` and its own new `lib/sprig/sprig_record_store/
lazy_record.rb`, which nothing else in either stack depends on). This second stack exists
specifically to demonstrate, with its own full benchmark run, that this idea's value is
real and substantial when it runs on top of the scheduler it's actually meant to pair
with.
