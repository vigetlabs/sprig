# Part 6: stream YAML/JSON parsing directly off IO instead of loading whole file

Port of the parser half (Option D) of the original investigation's `986bbad`, split from
that commit's other, independent halves (dependency-retention fixes -> this stack's part
3; opt-in disk spill -> part 7).

## What it does

`Parser::Yml`/`Json` no longer fully parse a file into memory via
`YAML.load`/`JSON.load`. Each now runs a `Psych::Parser`/`Oj::ScHandler` callback handler
(new `EventHandler` classes) that reads directly off the source `IO`, rewinding between
an eager pass that captures `options:` (small, cheap to build fully) and a lazy pass --
deferred until the returned `Enumerator` is actually iterated -- that streams `records:`
one row at a time, matching by key name (not position) since `options:`/`records:` can
appear in either order. `Parser::Csv` reverted to streaming `CSV.foreach` directly. This
only works because `Source#data` no longer closes the IO the instant `#parse` returns --
it now closes once the records enumerator is actually exhausted (or parsing fails).
Non-rewindable custom `:source` IOs (a real pipe, verified against `Errno::ESPIPE` on
`#rewind`) fall back to buffering once, same as before. Adds `oj` as a runtime dependency.

## How it helps

`YAML.load(data_io)` builds the *entire* parsed file -- every row of every one of the 5
models -- as one big nested Ruby structure before `Factory` ever converts the first row
into a `Descriptor`. That whole intermediate structure is gone once parsing streams a row
at a time straight into `Descriptor` construction. This effect scales with file size,
which is exactly why it's modest at 1K and dominant at 10K/100K.

## Empirical evidence

| Tier | Peak RSS | vs. part-5 | Storage-space-over-time | vs. part-5 |
|---|---:|---:|---:|---:|
| Small (1K) | 75.3 MB | -5.6% | 148.2 MB\*s | -5.5% |
| Medium (10K) | 115.2 MB | **-49.5%** | 2,652.0 MB\*s | **-44.6%** |
| Large (100K) | 509.0 MB | **-58.7%** | 138,504.7 MB\*s | **-54.9%** |

**This is the single largest contributor of any stage in this stack at medium scale**,
substantially larger than the original investigation's own ranking suggested, where it
was measured only in combination with the dependency-retention fixes and characterized as
mattering mainly for very large single files. Cumulative against the part-1 baseline,
this stage alone accounts for the majority of this stack's total medium-tier reduction.

## Additional notes

At the time this stage was ported, the full spec suite passed on the default config (201
examples) and all five Appraisals (rails-7.2/8.0/8.1, mongoid-8/9); standardrb clean.
`lib/sprig/{parser,source}.rb` and `sprig.gemspec` were untouched by every commit
`master` gained after the original investigation branched, so this was a clean, direct
port needing no integration work -- unlike parts 2 and 4, which both needed real
adaptation for `master`'s transactional `Planter`.

The medium-tier drop was confirmed reproducible, not a one-off outlier, across repeated
runs at that tier in an earlier pass of this investigation (part 5 in the ~215-276 MB
range, this stage in the ~125-133 MB range, non-overlapping) before the fixes described
in part 1/5's writeups landed -- the magnitude has since changed with the corrected
dataset, but the non-overlapping, reproducible-across-repeats character of the drop was
established directly, not assumed from a single run.
