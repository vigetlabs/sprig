# Part 3: deterministic `Dependency`; stop memoizing `Descriptor#dependency_id`/`#dependencies`

Port of the non-parser, non-spill half of the original investigation's `986bbad` --
the dependency-retention fixes that commit found while testing a large file end to end,
kept separate here from that commit's other two, independent changes (streaming
YAML/JSON parsers -> this stack's part 6; opt-in disk spill -> part 7).

## What it does

Two sources of retention that neither part 2 nor this stage's own predecessor addressed:

- `Dependency#id` was a cached `SecureRandom.uuid`, and `Dependency.for` kept every
  ever-seen `Dependency` alive for the whole process via a global `DependencyCollection`
  singleton, solely so a second `.for(klass, sprig_id)` call would return the same id.
  `Dependency#id` is now a deterministic string (`"klass.name sprig_id"`), so no registry
  is needed at all -- `DependencyCollection` is deleted entirely.
- `Descriptor` cached `dependency_id` and `dependencies` as memoized ivars even though
  the dependency sorter reads each exactly once, right after construction. Both are now
  computed on demand instead.

## How it helps

A global registry that remembers every id it's ever handed out, for the life of the
process, is exactly the kind of thing that grows without bound across a large run and
never shrinks. Making the id deterministic removes the need for the registry outright --
nothing has to be *remembered* to be reproduced. This is a smaller, cheaper change than
parts 2 or 6, but it's unconditionally beneficial and costs nothing to keep.

## Empirical evidence

| Tier | Peak RSS | vs. part-2 | Storage-space-over-time | vs. part-2 |
|---|---:|---:|---:|---:|
| Small (1K) | 92.7 MB | -0.7% | 169.9 MB\*s | -1.0% |
| Medium (10K) | 346.0 MB | -6.6% | 6,475.4 MB\*s | -4.9% |
| Large (100K) | 1,914.3 MB | -11.7% | 816,760.0 MB\*s | -8.9% |

The mechanism this stage targets is directly visible in the live object count, not just
inferred from the aggregate number: live `Sprig::Dependency` object count (medium tier)
grows to 55,020 and *stays there* for the whole run on part 2 (every dependency object
ever created remains reachable via the registry); on this part it peaks at 48,667
mid-run and ends at **zero** -- once the registry is deleted, `Dependency` objects are
collected like anything else.

## Additional notes

At the time this stage was ported, the full spec suite (181 examples) passed on the
default config and the mongoid-9 Appraisal (180, one fewer since Mongoid's own suite
doesn't carry the ActiveRecord-only `descriptor_spec` context); standardrb clean.

Also fixed a stale test description inherited from the port: `descriptor_spec` had a
"`#dependency_id` ... is memoized" test whose assertion never actually verified
memoization (just equality) -- the original port made this exact change but left the
misleading title in place. Renamed to describe what it verifies now: a stable id across
calls despite recomputing each time.

This stage's memory effect is real but modest on this harness specifically, and that's
expected, not a disappointing result: the dependency sorter this stack still uses at this
point (unchanged until part 4) already has to hold its own id/dependency bookkeeping for
the entire graph regardless of this fix, so the removed global-registry retention this
change targets shows up more clearly on longer-lived, more cross-referencing runs than
this stack's own tiers necessarily stress. The live-object-count evidence above is the
more direct confirmation that the mechanism works as intended, independent of how large
its share of the aggregate peak happens to be on this specific dataset.
