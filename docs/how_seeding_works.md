# How Sprig turns seed files into database records

This is a plain-English walkthrough of what actually happens between calling `sprig(...)`
in a seed file and rows showing up in your database.

## The short version

1. You list which classes to seed (`sprig [User, Post, Comment]`).
2. For each class, Sprig finds the matching data file (`users.yml`, `posts.csv`, etc.) and
   starts streaming it one row at a time.
3. Every row becomes a small placeholder (a `Descriptor`) the instant it's read, and is
   immediately offered to the planter -- there's no step where every file is fully parsed
   before planting can begin.
4. The planter checks whether everything that placeholder depends on
   (anything referenced via `sprig_record(Klass, id)`) has already been saved. If so, it
   builds the real record right now, evaluates its `<%= ... %>` values, and saves it. If
   not, the placeholder is held until the specific thing it's waiting on shows up.
5. Saving a record can immediately unblock other placeholders that were only waiting on
   it, which can immediately unblock others in turn, and so on.
6. Once every file has been streamed and nothing is left waiting, the run is done. If
   something is still stuck waiting at that point, it means a reference pointed at a
   `sprig_id` that doesn't exist anywhere, or a cycle -- Sprig reports which.

The rest of this doc goes through those steps in more detail, then explains what keeps
memory use low on large seed data sets.

## Step by step

### 1. Directives: what to seed

`sprig [User, Post, Comment]` (in `Sprig::Helpers#sprig`) turns each entry in that list
into a `Sprig::Directive` -- either a plain class, or a hash like
`{class: User, find_existing_by: [:username]}` to hold custom options. A `Directive`
knows how to find its own data file by convention (`user.class.tableize`, e.g. `Post` →
`posts.yml`/`.json`/`.csv`) via `Sprig::Source`, unless you've pointed it at a custom
`:source`/`:parser`.

### 2. Parsing: streaming a file into rows

`Sprig::Source` hands the file's IO to the right `Sprig::Parser` (`Yml`, `Json`, or
`Csv`, chosen by file extension). Each parser exposes any file-level `options:` (like
`find_existing_by`) as a small, eagerly-built hash, and exposes `records:` as a lazy
`Enumerator` that reads one row at a time directly off the IO as it's iterated, rather
than parsing the whole file into memory up front. `Yml` and `Json` do this via a
streaming event-handler (`Psych::Parser`/`Oj::ScHandler` callbacks); `Csv` streams via
`CSV.foreach`. The source IO stays open until that enumerator is fully drained.

### 3. Descriptors: a cheap placeholder for every row

For each row a parser yields, `Sprig::Seed::Factory` builds a `Sprig::Seed::Descriptor`
and offers it directly to the planter (see step 4) -- there's no intermediate collection
holding every row from every file at once. A descriptor is intentionally lightweight: it
just holds the class, the row's raw data, and the options -- nothing has been "built" yet.
From that raw data it can cheaply answer two questions, computed fresh each time rather
than cached, since nothing needs to hold onto them once the planter has acted on them:

- **What's my own identity?** (`dependency_id`, based on its class + `sprig_id`)
- **What do I depend on?** (`dependencies`) -- found by scanning the row's values for
  `sprig_record(Klass, id)` written _inside_ an ERB tag (`<%= ... %>`). A value that just
  happens to contain that text without the ERB wrapper doesn't count -- only genuine
  computed references do.

Nothing is evaluated at this point. A value like `<%= 1.week.ago %>` or
`<%= sprig_record(Post, 1).id %>` is just inspected as text to find dependency
references; the actual Ruby expression only runs later, once that specific record is
about to be saved.

### 4. Scheduling: planting as soon as it's safe, holding otherwise

`Sprig::Planter` receives descriptors one at a time, as they're parsed, via `<<`. For
each one, it checks whether every dependency id it needs has already been planted:

- **Nothing missing** -- the descriptor (and anything that cascades from it, see below)
  is planted immediately.
- **Something missing** -- the descriptor is filed under each unmet dependency id it's
  waiting on. Nothing else happens to it until the matching id is planted.

There's no global, whole-data-set sort. A descriptor's dependencies can point anywhere
-- earlier in the same file, later in the same file, or a totally different file -- but
the planter doesn't need to see the whole picture at once to know what's safe to plant
right now; it only needs to know what's already been planted.

Planting a record can satisfy the last thing one or more waiting descriptors needed,
which makes them plantable too, which can in turn unblock others. This cascade is driven
by an explicit queue, not recursion, so a long self-referencing chain doesn't overflow
the call stack no matter how deep it goes.

If `Sprig.configuration.spill_seed_rows_to_disk` is enabled (off by default), a descriptor
writes its raw row data to a small disk-backed log (`Sprig::RawRowStore`) at the moment
it's determined to be waiting, and only reads it back once, right before it's actually
planted -- freeing the in-memory copy for however long it ends up waiting. A descriptor
that's plantable the instant it's offered never touches this at all.

### 5. Planting: building and saving one record

Once a descriptor is ready, `descriptor.to_entry` builds the real thing: a
`Sprig::Seed::Entry`, which evaluates any `<%= ... %>` expressions in the row (including
`sprig_record(...)` calls, which succeed because nothing is planted until everything it
depends on already has been), assigns the result to a new or existing model instance,
and saves it.

The whole run -- every descriptor offered, every record planted -- happens inside a
database transaction when the adapter supports it (`Sprig.configuration.wrap_in_transaction`,
on by default), so an error partway through rolls back everything, not just the record
that failed.

### 6. Remembering what was saved

After a record is saved, `Sprig::SprigRecordStore` keeps a note of it, keyed by class and
`sprig_id` -- specifically, the record's real primary key, not the record itself. Later,
when some other record's `<%= sprig_record(Klass, id) %>` needs to resolve that reference,
`sprig_record` returns a small lazy proxy (`Sprig::SprigRecordStore::LazyRecord`) that
already knows the id -- calling `.id` on it (by far the most common usage, e.g. setting a
foreign key) is answered immediately, with no database access at all. Calling anything
*else* on it -- an attribute, an association -- fetches the real record from the database
at that point, once, and delegates. This is a separate, simpler lookup from the dependency
bookkeeping in step 4 -- that bookkeeping decides _when_ it's safe to plant something; the
record store answers _"what did that record actually end up as, once saved?"_ as cheaply
as whatever's actually being asked for allows.

### 7. Finishing up

Once every file has been fully streamed and offered, anything still waiting means a
structural problem: either a genuine reference to a `sprig_id` that appears nowhere in
the data (`MissingDependencyError`), or a cycle, directly or through a chain
(`CircularDependencyError`). A missing reference is reported in preference to a cycle
when both are present in the same stuck set, since it's the more specific diagnosis.

## Keeping memory use low

A few properties of the design above are what keep memory use low, even on large,
badly-ordered seed data sets.

**Only genuinely-blocked descriptors are held in memory.** Nothing waits for a global
sort of the whole data set before planting starts, and nothing keeps a permanent record
of everything ever offered -- the planter's own bookkeeping only ever holds descriptors
that are still actually waiting on something. Once a descriptor plants, it's simply
gone; nothing keeps a reference to it.

**Parsing never holds a whole file in memory.** `Yml` and `Json` stream rows one at a
time directly off the file's IO; `Csv` does the same via `CSV.foreach`. Peak memory from
parsing scales with one row, not with file size.

**Rows stay lightweight until the instant they're planted.** A `Descriptor` is a thin
wrapper around raw row data -- it only becomes a fully built `Entry`, with its `<%= ... %>`
values evaluated and its attributes wrapped, at the exact moment it's about to be saved.
Anything still waiting is sitting in memory as a cheap descriptor, not a fully built
record.

**Dependency ids cost nothing to keep around.** A dependency id is just a deterministic
string (`"klass.name sprig_id"`), computed on demand from a descriptor's own already-held
data. There's no global registry that has to remember every id it's ever handed out.

**Nothing keeps a saved record alive on purpose, and looking one up back rarely touches
the database at all.** `SprigRecordStore` retains only the saved id, not the record
itself -- so an already-planted record is free to be garbage collected like anything
else once nothing else in your own code is holding a reference to it. And because
`sprig_record(...)` returns a lazy proxy rather than eagerly re-fetching, the extremely
common case of just reading a referenced record's id back off (`sprig_record(Klass, id).id`,
e.g. to set a foreign key) never queries the database in the first place -- only a usage
that actually needs an attribute or association off the referenced record pays for a real
fetch, and even then, at most once per reference.

**Spilling waiting rows to disk is available, but opt-in.** For a large, badly-ordered
seed run where a lot of descriptors end up waiting a long time,
`Sprig.configuration.spill_seed_rows_to_disk = true` moves their raw row data out of
Ruby's heap and onto a small append-only log file, at the cost of one disk read/write per
descriptor that actually waits. It's off by default because that cost isn't worth paying
for small or well-ordered seed data, where few or no descriptors wait long enough for it
to matter.

## Where things live in the code

| Concept                                     | File                                                                                                                           |
| -------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| Entry point (`sprig`/`sprig_shared`)         | `lib/sprig/helpers.rb`                                                                                                         |
| Directive (what to seed, with what options)  | `lib/sprig/directive.rb`, `lib/sprig/directive_list.rb`                                                                        |
| Finding and streaming a data file            | `lib/sprig/source.rb`, `lib/sprig/parser/*.rb`, `lib/sprig/parser/yml/event_handler.rb`, `lib/sprig/parser/json/event_handler.rb` |
| Turning rows into placeholders               | `lib/sprig/seed/factory.rb`, `lib/sprig/seed/descriptor.rb`                                                                    |
| Dependency identity                          | `lib/sprig/dependency.rb`                                                                                                      |
| Optionally spilling waiting rows to disk     | `lib/sprig/raw_row_store.rb`, `lib/sprig/configuration.rb` (`spill_seed_rows_to_disk`)                                          |
| Building and saving the real record          | `lib/sprig/seed/entry.rb`, `lib/sprig/seed/attribute.rb`, `lib/sprig/seed/attribute_collection.rb`, `lib/sprig/seed/record.rb` |
| Driving the plant-when-ready scheduler       | `lib/sprig/planter.rb`                                                                                                         |
| Looking up already-planted records           | `lib/sprig/sprig_record_store.rb`, `lib/sprig/sprig_record_store/lazy_record.rb`                                               |
