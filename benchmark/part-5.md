# Part 5: stop retaining full records in `SprigRecordStore`; re-fetch lazily by id

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
record forever, purely so a handful of later references _might_ look it up, is a cost
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

| Tier         |   Peak RSS | vs. part-4 | Storage-space-over-time | vs. part-4 |
| ------------ | ---------: | ---------: | ----------------------: | ---------: |
| Small (1K)   |    79.8 MB |     -14.7% |             156.8 MB\*s |      -6.8% |
| Medium (10K) |   228.2 MB | **-41.8%** |           4,787.5 MB\*s | **-27.8%** |
| Large (100K) | 1,232.0 MB | **-39.0%** |         306,955.2 MB\*s | **-58.4%** |

Wall time, part-5 vs. part-4: small 2.019s -> 2.024s (flat); medium 23.47s -> 21.96s
(**-6.4%**); large 1,143.1s -> 458.5s, a **-59.9% improvement, not a cost** -- the
wall-time win grows sharply with scale.
