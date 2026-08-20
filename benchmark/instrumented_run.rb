# DIAGNOSTIC TOOL -- not part of the Sprig library, not required by run_benchmark.rb.
#
# Produced the memory/object-count traces and final-breakdown snapshots cited in the
# "Deep dive: what the traces actually show" section of benchmark/README.md. Where
# run_benchmark.rb gives one before/after peak-RSS number per run (via `/usr/bin/time
# -l`), this script polls RSS and GC.stat throughout the run and, once, right after
# planting finishes, breaks down exactly what's still reachable in the specific
# structures this investigation was about: SprigRecordStore's held records, the old
# whole-graph Planter#dependency_sorted_seeds array, and the incremental scheduler's
# waiting/pending set.
#
# Usage (same directives/schema as run_benchmark.rb; add SPILL=1 to enable
# spill_seed_rows_to_disk on branches where it exists):
#   bundle exec ruby benchmark/instrumented_run.rb <dataset-dir> <out.csv> [interval-s]
#
# Writes a CSV trace to <out.csv> (columns: t, rss_kb, heap_live_slots,
# total_allocated, total_freed, gc_count, planted) and a companion
# <out>_final_breakdown.txt with the post-run ObjectSpace snapshot plus the
# memory-time integral (see #memory_time_integral_kb_seconds below). [interval-s]
# defaults to 0.5s -- at the 100K-row tier, ObjectSpace.each_object/reachable_objects_from
# walks scale with total live heap size and can start competing with the actual
# planting work for the GVL; this is why per-tick sampling here is limited to O(1)
# GC.stat/ps counters, with the expensive ObjectSpace walk done exactly once, at the end,
# rather than repeated on every tick (see benchmark/README.md's instrumented-runs section
# for the ~11-minute-vs-40-minute discovery that led to this design).
#
# Raw traces from the runs cited in benchmark/README.md are preserved outside this repo
# at ~/sprig-benchmark-v3-raw/ (large, run-specific data, not meant for source control) --
# this script is what produced them, and re-running it reproduces them.
require "tsort"
require "pg"
require "active_record"
require "logger"
require "objspace"
require "csv"
require "sprig"

Sprig.adapter = :active_record
Sprig.configure { |c| c.logger = Logger.new(File::NULL) }

if ENV["SPILL"] == "1"
  if Sprig.configuration.respond_to?(:spill_seed_rows_to_disk=)
    Sprig.configure { |c| c.spill_seed_rows_to_disk = true }
  else
    abort "spill_seed_rows_to_disk is not available on this branch -- SPILL=1 doesn't apply here."
  end
end

ActiveRecord::Base.establish_connection(
  adapter: "postgresql",
  host: ENV.fetch("SPRIG_BENCHMARK_PG_HOST", "localhost"),
  port: ENV.fetch("SPRIG_BENCHMARK_PG_PORT", "5433").to_i,
  user: ENV.fetch("SPRIG_BENCHMARK_PG_USER", "postgres"),
  password: ENV.fetch("SPRIG_BENCHMARK_PG_PASSWORD", "postgres"),
  database: ENV.fetch("SPRIG_BENCHMARK_PG_DATABASE", "sprig_benchmark")
)
ActiveRecord::Schema.verbose = false
unless ActiveRecord::Base.connection.table_exists?(:customers)
  ActiveRecord::Schema.define do
    create_table(:customers) { |t|
      t.string :name
      t.string :contact_email
      t.date :signed_up_on
      t.boolean :active
      t.decimal :annual_revenue
      t.integer :employee_count
      t.text :notes
    }
    create_table(:tags) { |t|
      t.string :name
      t.string :category
    }
    create_table(:projects) { |t|
      t.string :title
      t.string :status
      t.decimal :budget
      t.date :starts_on
      t.boolean :billable
      t.integer :priority
      t.integer :customer_id
    }
    create_table(:tasks) { |t|
      t.string :title
      t.text :description
      t.date :due_on
      t.decimal :estimated_hours
      t.boolean :completed
      t.string :assignee_name
      t.integer :project_id
    }
    create_table(:project_tags) { |t|
      t.integer :project_id
      t.integer :tag_id
      t.date :added_on
    }
  end
end
ActiveRecord::Base.connection.execute("TRUNCATE customers, tags, projects, tasks, project_tags")

class Customer < ActiveRecord::Base; end

class Tag < ActiveRecord::Base; end

class Project < ActiveRecord::Base; end

class Task < ActiveRecord::Base; end

class ProjectTag < ActiveRecord::Base; end

class Seeder
  include Sprig::Helpers
end

dir = ARGV[0]
out_path = ARGV[1] || "/tmp/mem_samples.csv"
sample_interval = (ARGV[2] || "0.5").to_f
raise "usage: instrumented_run.rb <dataset-dir> <out-csv> [sample-interval-seconds]" unless dir

# ---------------------------------------------------------------------------
# Instrumentation. Purely diagnostic -- not part of the library itself.
# ---------------------------------------------------------------------------

records_planted = [0]
Sprig::SprigRecordStore.class_eval do
  alias_method :__save_uninstrumented, :save
  define_method(:save) do |record, sprig_id|
    result = __save_uninstrumented(record, sprig_id)
    records_planted[0] += 1
    result
  end
end

# Rough deep-size estimate via one reachability walk from a single sample object.
# Used to estimate "bytes per retained item" so it can be multiplied by a live
# count instead of walking every item in a large collection every tick.
def deep_size_estimate(obj, max_objects: 5_000)
  return 0 if obj.nil?
  visited = {}
  stack = [obj]
  total = 0
  count = 0
  until stack.empty? || count > max_objects
    o = stack.pop
    id = o.object_id
    next if visited[id]
    visited[id] = true
    count += 1
    begin
      total += ObjectSpace.memsize_of(o)
    rescue
    end
    begin
      ObjectSpace.reachable_objects_from(o).each do |child|
        next if child.is_a?(Module) || child.is_a?(Class)
        immediate = child.frozen? && (child.is_a?(Symbol) || child.is_a?(Integer))
        stack.push(child) unless immediate
      end
    rescue
    end
  end
  total
end

def live_instance_of(klass)
  return nil unless klass
  found = nil
  ObjectSpace.each_object(klass) do |o|
    found = o
    break
  end
  found
end

def sprig_record_store_snapshot
  store = Sprig::SprigRecordStore.instance
  records = store.instance_variable_get(:@records) || {}
  total_count = 0
  sample_value = nil
  records.each_value do |sub|
    total_count += sub.size
    sample_value ||= sub.values.first
  end
  per_item_bytes = sample_value ? deep_size_estimate(sample_value) : 0
  [total_count, per_item_bytes, total_count * per_item_bytes]
end

# Old (pre-Descriptor) pipeline: Planter memoizes the whole sorted-seed array in
# @dependency_sorted_seeds and iterates it with #each, so it stays referenced for
# the entire planting loop.
def planter_retained_array_snapshot
  planter = live_instance_of(defined?(Sprig::Planter) ? Sprig::Planter : nil)
  return [nil, nil, nil] unless planter
  arr = planter.instance_variable_get(:@dependency_sorted_seeds)
  return [nil, nil, nil] unless arr
  sample = arr.first
  per_item_bytes = sample ? deep_size_estimate(sample) : 0
  [arr.size, per_item_bytes, arr.size * per_item_bytes]
end

# New (incremental scheduler) pipeline: Planter holds blocked descriptors in
# @waiting_for / @pending_count until their dependency shows up.
def planter_waiting_snapshot
  planter = live_instance_of(defined?(Sprig::Planter) ? Sprig::Planter : nil)
  return [nil, nil, nil] unless planter
  pending = planter.instance_variable_get(:@pending_count)
  return [nil, nil, nil] unless pending
  count = pending.size
  sample = pending.keys.first
  per_item_bytes = sample ? deep_size_estimate(sample) : 0
  [count, per_item_bytes, count * per_item_bytes]
end

# Storage-space-over-time: the area under the RSS-vs-time curve, via the
# trapezoidal rule over the *actual* sampled timestamps (not an assumed fixed
# interval -- real intervals drift under load, e.g. under GVL contention with the
# main thread's own work, so this doesn't assume samples land exactly
# sample_interval apart). A run holding 10MB steady for 5s scores 50 MB-seconds,
# matching a run holding 50MB steady for 1s -- same total "space x time" even
# though peak RSS alone would rank them very differently. Distinguishes "high but
# brief" from "moderate but sustained" memory use, which peak RSS alone can't.
def memory_time_integral_kb_seconds(samples)
  total = 0.0
  samples.each_cons(2) do |a, b|
    dt = b[:t] - a[:t]
    avg_kb = (a[:rss_kb] + b[:rss_kb]) / 2.0
    total += avg_kb * dt
  end
  total
end

samples = []
start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
stop = false

# Every interval-tick sample is pure O(1) polling (ps -o rss=, GC.stat counters) --
# no ObjectSpace.each_object/reachable_objects_from heap walk. Those walks cost is
# proportional to total live heap size, which only grows through the run; doing
# them repeatedly (even gated to every few seconds) meant the walk itself grew
# slower than the interval meant to bound it, and it competed for the GVL with
# the actual planting work on the main thread. They're computed exactly once,
# after planting finishes, as a single final breakdown snapshot instead.
sampler = Thread.new do
  until stop
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
    rss_kb = `ps -o rss= -p #{Process.pid}`.to_i
    gc = GC.stat

    samples << {
      t: elapsed.round(3),
      rss_kb: rss_kb,
      heap_live_slots: gc[:heap_live_slots],
      total_allocated: gc[:total_allocated_objects],
      total_freed: gc[:total_freed_objects],
      gc_count: gc[:count],
      planted: records_planted[0]
    }
    sleep sample_interval
  end
end

customers_path = File.join(dir, "customers.yml")
tags_path = File.join(dir, "tags.yml")
projects_path = File.join(dir, "projects.yml")
tasks_path = File.join(dir, "tasks.yml")
project_tags_path = File.join(dir, "project_tags.yml")

directives = [
  {class: ProjectTag, source: File.open(project_tags_path), parser: Sprig::Parser::Yml},
  {class: Task, source: File.open(tasks_path), parser: Sprig::Parser::Yml},
  {class: Project, source: File.open(projects_path), parser: Sprig::Parser::Yml},
  {class: Tag, source: File.open(tags_path), parser: Sprig::Parser::Yml},
  {class: Customer, source: File.open(customers_path), parser: Sprig::Parser::Yml}
]

wall_start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
Seeder.new.sprig(directives)
wall_end = Process.clock_gettime(Process::CLOCK_MONOTONIC)

stop = true
sampler.join

warn "planted customers=#{Customer.count} tags=#{Tag.count} projects=#{Project.count} tasks=#{Task.count} project_tags=#{ProjectTag.count}"
warn "wall_time=#{(wall_end - wall_start).round(2)}s"

headers = samples.first.keys
CSV.open(out_path, "w") do |csv|
  csv << headers
  samples.each { |s| csv << headers.map { |h| s[h] } }
end
warn "wrote #{samples.size} samples to #{out_path}"

entry_count = defined?(Sprig::Seed::Entry) ? ObjectSpace.each_object(Sprig::Seed::Entry).count : nil
descriptor_count = defined?(Sprig::Seed::Descriptor) ? ObjectSpace.each_object(Sprig::Seed::Descriptor).count : nil
ar_count = ObjectSpace.each_object(ActiveRecord::Base).count
dependency_count = defined?(Sprig::Dependency) ? ObjectSpace.each_object(Sprig::Dependency).count : nil
store_count, store_per_item, store_bytes = sprig_record_store_snapshot
sorted_len, sorted_per_item, sorted_bytes = planter_retained_array_snapshot
waiting_len, waiting_per_item, waiting_bytes = planter_waiting_snapshot
memory_kb_seconds = memory_time_integral_kb_seconds(samples)

breakdown_path = out_path.sub(/\.csv\z/, "_final_breakdown.txt")
File.write(breakdown_path, <<~TEXT)
  entry_count=#{entry_count}
  descriptor_count=#{descriptor_count}
  ar_count=#{ar_count}
  dependency_count=#{dependency_count}
  store_count=#{store_count} store_per_item_bytes=#{store_per_item} store_bytes_est=#{store_bytes}
  sorted_seeds_len=#{sorted_len} sorted_seeds_per_item_bytes=#{sorted_per_item} sorted_seeds_bytes_est=#{sorted_bytes}
  waiting_len=#{waiting_len} waiting_per_item_bytes=#{waiting_per_item} waiting_bytes_est=#{waiting_bytes}
  memory_kb_seconds=#{memory_kb_seconds.round(1)} memory_mb_seconds=#{(memory_kb_seconds / 1024.0).round(2)}
TEXT
warn "wrote final breakdown to #{breakdown_path}"
