# Part 3: deterministic `Dependency`; stop memoizing `Descriptor#dependency_id`/`#dependencies`

## What it does

Resolves two additional sources of data retention:

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
nothing has to be _remembered_ to be reproduced. This is a smaller, cheaper change than
parts 2 or 6, but it's unconditionally beneficial and costs nothing to keep.

## Empirical evidence

| Tier         |   Peak RSS | vs. part-2 | Storage-space-over-time | vs. part-2 |
| ------------ | ---------: | ---------: | ----------------------: | ---------: |
| Small (1K)   |    92.7 MB |      -0.7% |             169.9 MB\*s |      -1.0% |
| Medium (10K) |   346.0 MB |      -6.6% |           6,475.4 MB\*s |      -4.9% |
| Large (100K) | 1,914.3 MB |     -11.7% |         816,760.0 MB\*s |      -8.9% |

The mechanism this stage targets is directly visible in the live object count, not just
inferred from the aggregate number: live `Sprig::Dependency` object count (medium tier)
grows to 55,020 and _stays there_ for the whole run on part 2 (every dependency object
ever created remains reachable via the registry); on this part it peaks at 48,667
mid-run and ends at **zero** -- once the registry is deleted, `Dependency` objects are
collected like anything else.

## Additional notes

This stage's memory effect is real but modest on this harness specifically, and that's
expected, not a disappointing result: the dependency sorter this stack still uses at this
point (unchanged until part 4) already has to hold its own id/dependency bookkeeping for
the entire graph regardless of this fix, so the removed global-registry retention this
change targets shows up more clearly on longer-lived, more cross-referencing runs than
this stack's own tiers necessarily stress. The live-object-count evidence above is the
more direct confirmation that the mechanism works as intended, independent of how large
its share of the aggregate peak happens to be on this specific dataset.
