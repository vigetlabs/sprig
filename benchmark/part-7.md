# Part 7: opt-in `spill_seed_rows_to_disk`

Port of the `RawRowStore`/spill half (Option C) of the original investigation's
`986bbad`, with the "only spill when actually deferred" correction from that same
investigation's later fix folded in from the start -- no reason to ship the
known-inefficient unconditional-spill version first just to immediately fix it.

## What it does

New `Sprig::RawRowStore` (a single append-only log file + an in-memory id -> offset
index), enabled via `Sprig.configure { |c| c.spill_seed_rows_to_disk = true }`, off by
default. `Descriptor#initialize` always holds `@raw_attrs` in memory, same as when
spilling is disabled; `Planter#<<` calls the new `Descriptor#spill_to_disk!` only in the
branch where a descriptor is actually deferred (unmet dependencies present) -- a
descriptor that's ready immediately never touches `RawRowStore` at all.
`RawRowStore#fetch` deletes its index entry after returning a row, since a descriptor's
raw data is only ever needed once (right before planting).

## How it helps

For a badly-ordered seed run, a meaningful fraction of descriptors end up waiting a long
time before they can plant. Moving their raw row data out of Ruby's heap and onto a
small disk-backed log, only for the ones that actually end up waiting, trades a bounded
amount of disk I/O for memory that would otherwise sit idle in the Ruby heap for however
long the wait lasts.

## Empirical evidence

**With `SPILL` off (this stack's default), merely having the feature available and
unused**, vs. part 6:

| Tier | Peak RSS | vs. part-6 | Storage-space-over-time | vs. part-6 |
|---|---:|---:|---:|---:|
| Small (1K) | 75.3 MB | -0.0% | 148.6 MB\*s | +0.3% |
| Medium (10K) | 122.1 MB | +6.0% | 2,670.2 MB\*s | +0.7% |
| Large (100K) | 556.1 MB | +9.3% | 132,302.6 MB\*s | -4.5% |

Small tier is exactly flat, as expected -- the feature costs nothing when disabled. The
medium/large peak-RSS upticks (+6.0%/+9.3%) are small and not mechanistically explained
here; the storage-space-over-time figures don't show the same consistent uptick (roughly
flat at medium, actually down at large), so this isn't asserted as a real per-run cost of
merely having the code path present, just noted as measured.

**With `SPILL=1` (opt-in, explicitly enabled), vs. `SPILL` off on the same branch:**

| Tier | Peak RSS delta | Storage-space-over-time delta |
|---|---:|---:|
| Small (1K) | -3.2% | **+20.9%** |
| Medium (10K) | -9.9% | -4.6% |
| Large (100K) | **-26.2%** | **-22.5%** |

**The storage-space-over-time metric disagrees with peak RSS at small tier, and that
disagreement is real, not noise.** `SPILL=1` lowers peak RSS at small tier but *raises*
the memory-time integral, because `SPILL=1`'s small-tier wall time is itself longer
(2.02s -> 2.53s, +25%) -- holding a somewhat lower amount of memory for a meaningfully
longer time nets out to *more* total storage-space-over-time, not less. At medium and
large tier both metrics agree it's a win, and the win grows with scale on both metrics --
peak RSS -9.9% at medium, -26.2% at large; storage-space-over-time -4.6% at medium,
-22.5% at large. This is exactly the distinction peak RSS alone can't make at small
scale, and it's a direct, concrete demonstration of why tracking both metrics is worth
the extra instrumentation.

Verified via instrumentation, not just re-reading the diff, when this stage was first
built: prepending call counters onto `RawRowStore#put`/`#fetch` and running this stack's
small tier showed exactly 4,204 puts and 4,204 fetches -- a 1:1 match confirming no
leaked or double-fetched entries, against 4,204 of that tier's 5,520 total descriptors
(76%) that genuinely waited at some point, consistent with every directive being
declared dependency-last in this harness.

## Additional notes

At the time this stage was first built, the full spec suite (219 examples) passed on the
default config and all five Appraisals (rails-7.2/8.0/8.1, mongoid-8/9); standardrb
clean. An earlier pass of this investigation (on the pre-fix dataset) found this
feature's benefit notably stronger than the original, pre-`master`-rebase investigation
found (which measured only a 5-6% reduction in its best-case scenario and explicitly
didn't recommend enabling it by default) -- the difference is this harness's every
directive being declared dependency-last by design, so a much larger fraction of
descriptors are genuinely long-held than in the original's mostly well-ordered test
scenarios, exactly the condition this feature's own design doc says it should help. Small
scale still shows limited-to-negative benefit on the storage-space-over-time metric,
matching the original investigation's own finding that spilling isn't worth it for small
or well-ordered seed data -- too few, too-cheap-to-hold rows for `RawRowStore`'s fixed
per-record disk I/O cost to pay for itself. Kept opt-in rather than default, matching the
original investigation's own recommendation.

See [`benchmark/README.md`](README.md) for the full, final, stack-wide results, "Why the
reorder changes the story" for the two bugs found and fixed during this investigation
(both described in part 1 and part 5's own writeups), and "Where to stop" for the overall
recommendation.
