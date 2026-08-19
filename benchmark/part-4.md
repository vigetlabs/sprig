# Part 4: replace whole-graph tsort with incremental plant-when-ready scheduling

Port of the original investigation's `fb9c3e4`.

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
badly-ordered self-referencing hierarchy -- independent of any memory number below, and
the reason this stage is treated as a non-negotiable floor regardless of stack position
(see `benchmark/README.md`'s "Where to stop").

The memory mechanism itself is real too: instead of holding the whole graph until
everything is sorted, only descriptors genuinely blocked on something not yet seen are
held at all, and the "planted" bookkeeping is a bare string, not a reference to anything
heavy.

## Empirical evidence

| Tier | Peak RSS | vs. part-3 | Storage-space-over-time | vs. part-3 |
|---|---:|---:|---:|---:|
| Small (1K) | 93.6 MB | +1.0% | 168.3 MB\*s | -0.9% |
| Medium (10K) | 392.4 MB | +13.4% | 6,630.9 MB\*s | +2.4% |
| Large (100K) | 2,020.9 MB | +5.6% | 737,494.4 MB\*s | -9.7% |

**Peak RSS moved in the direction opposite to what the mechanism above predicts, and
that's reported plainly rather than explained away.** Medium tier is +13.4% versus part
3, not an improvement -- a bigger gap than the roughly-flat result seen on an earlier,
pre-fix pass of this same comparison. This dataset's dependency graph is only 2 hops deep
(`ProjectTag`/`Task` -> `Project` -> `Customer`) regardless of N, so it was never going to
stress the old whole-graph scheduler's memory the way a long, badly-ordered single chain
does -- that's exactly the scenario the crash-check above exercises directly, rather than
by proxy through a peak-RSS number this dataset isn't shaped to move favorably. This
part's justification does not depend on this number either way.

**Re-investigated directly, rather than left as a single-run anomaly.** Ran 4 interleaved
trials each of part-3 and part-4 at medium tier (part-3, part-4, part-3, part-4, ...,
specifically to separate a real code effect from any session-specific noise on the
machine doing the measuring): part-3 peak RSS ranged 344.9-375.6 MB (mean 355.5, sd 11.9);
part-4 ranged 392.8-399.5 MB (mean 397.4, sd 2.7). Every part-4 trial exceeded every
part-3 trial -- complete separation, not overlapping distributions -- confirming this is
a real, reproducible difference between the two branches' code, not noise from what else
was running on the machine at the time. (Wall time, measured in the same trials, *did*
show a real session-noise artifact unrelated to this finding: one part-4 trial ran 27.0s
against a baseline of ~21.2-21.9s for its own other three trials, while that same trial's
peak RSS was perfectly in line with its siblings -- a timing blip, not a memory one.)

One structural clue considered during that re-investigation turned out to be a
measurement artifact, not a real lead, and is recorded here rather than quietly dropped:
the single-sample deep-size estimate this instrumentation uses for `SprigRecordStore`'s
contents differed consistently between the two branches, which looked at first like a
real per-record cost difference. Checking directly which record each branch's sampler
caught first: part-3 (whole-graph tsort) samples a `Customer` -- tsort visits true
independents first; part-4 (the scheduler) samples a `Project` -- the scheduler plants
whatever's immediately ready, and that's the first `Project` with no `customer_id`
(~30% of them have none, by this dataset's own design). Different record type sampled,
different estimate; not a real difference in per-record cost between the branches.
Likewise, `descriptor_count`/`dependency_count` at the final snapshot are not a reliable
structural signal here: across the 4 re-investigation trials, part-4's own final
`descriptor_count` ranged from ~1,500 to ~14,700 -- an order of magnitude of run-to-run
variance within the *same* branch, consistent with this being ordinary GC sweep lag (see
the Results section's own caveat about single-snapshot live-object counts) rather than a
stable measurement of anything. Citing one such number as if representative would have
been misleading.

What does look like a real, if not fully verified, lead: storage-space-over-time tells a
more precise story than peak RSS alone. Excluding the one wall-time-outlier trial above,
part-4's medium-tier MB-seconds exceeds part-3's by only ~4.5%, well below the ~11.8%
peak-RSS gap in the same trials. A cost concentrated in a brief spike rather than
sustained across the run is consistent with how this dataset's dependency shape can
produce one: only 20 `Tag`s exist, shared across 25,000 `ProjectTag`s, so a single `Tag`
being offered can unblock roughly a thousand already-Project-satisfied `ProjectTag`s in
one cascade, planted in a burst by the scheduler introduced in this part. This is a
plausible mechanism, not a confirmed one -- nothing in this investigation instruments the
cascade queue directly to verify it, and it's recorded here as the current best lead
rather than a settled answer.

## Additional notes

Beyond the port itself, this stage needed integration work entirely caused by `master`'s
transactional `Planter` not existing when the original investigation was written -- that
older stack had no transaction to wrap, so this problem never came up there:

- The old whole-graph `Planter` took `seeds` upfront and could read a class off any of
  them for Mongoid's transaction anchor. The new incremental `Planter` has no such list --
  descriptors only exist once offered via `<<`, and offering has to happen *inside* the
  open transaction for rollback to actually undo anything. Resolved by having
  `Planter#sprig` take a block (population happens inside it) and giving `Planter.new` an
  optional anchor-class hint, derived from the *first directive definition* -- available
  before any file is opened.
- `transactional_anchor_class` is memoized, since `Planter`'s own error-path calls it
  twice per run and re-deriving it from a data source consumed in between would silently
  break.

At the time this stage was ported, the full spec suite passed on the default config (182
examples) and all five Appraisals (rails-7.2/8.0/8.1, mongoid-8/9) -- the mongoid-9 run
caught a real gap in the ported `planter_spec.rb` doubles (a missing `warning` stub for
the no-anchor-hint path) that the default ActiveRecord suite couldn't have caught, since
ActiveRecord's anchor never depends on the hint. One e2e assertion in `spec/sprig_spec.rb`
was loosened from a specific insertion order to `contain_exactly` (an STI
cross-referencing test) -- Sprig only ever promised dependencies-before-dependents, not a
specific order among mutually-independent records, and this algorithm's tie-breaking
differs from the old tsort's.
