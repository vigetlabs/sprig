# Plants a Customer/Tag/Project/Task/ProjectTag dataset (see generate_dataset.rb)
# through the real, public Sprig pipeline -- Sprig::Helpers#sprig, real ActiveRecord
# models, real saves -- against a real, separate PostgreSQL server, not in-process
# SQLite: SQLite's own storage (B-tree pages, buffers) runs inside the same OS process
# being measured and would otherwise be counted alongside Sprig's own memory. Only
# Sprig's public API is used, so this same script runs unmodified against every branch
# in this comparison.
#
# Every directive is declared and offered in dependency-last order: ProjectTag (which
# needs a Project AND a Tag) first, then Task (needs a Project), then Project (needs a
# Customer), then the two independent models last. This is the only ordering this
# benchmark suite exercises -- see benchmark/README.md. ProjectTag additionally depends
# on two independent things at once, unlike every other model here, which depends on at
# most one.
#
# Usage:
#   ruby benchmark/generate_dataset.rb /tmp/bench_1k 1000
#   bundle exec ruby benchmark/run_benchmark.rb /tmp/bench_1k
#
# Wrap with /usr/bin/time -l (macOS) / -v (Linux) for isolated peak-RSS + wall-time
# measurement. Run once per process -- never loop multiple branches/scenarios inside
# one Ruby process, since Ruby's allocator reuses warmed-up memory arenas across
# repeated allocations in the same process and would make later runs look artificially
# cheap.
#
# Set SPILL=1 to enable Sprig.configuration.spill_seed_rows_to_disk, once that option
# exists on this branch -- aborts with a clear message rather than silently no-opping
# on branches where it doesn't.
#
# Postgres connection: SPRIG_BENCHMARK_PG_{HOST,PORT,USER,PASSWORD,DATABASE}, defaulting
# to match the `docker run` command in benchmark/README.md. Tables are truncated at the
# start of each run, since a real Postgres server persists data between invocations
# (unlike SQLite ":memory:", which resets automatically per process).
require "tsort" # implicit dependency of DependencySorter on branches that still have it;
# required explicitly since Ruby 3.4 no longer autoloads it, and this script has to run
# unmodified against every branch in the comparison.
require "pg"
require "active_record"
require "logger"
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
raise "usage: run_benchmark.rb <dataset-dir>" unless dir

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

Seeder.new.sprig(directives)

warn "planted customers=#{Customer.count} tags=#{Tag.count} projects=#{Project.count} tasks=#{Task.count} project_tags=#{ProjectTag.count}"
