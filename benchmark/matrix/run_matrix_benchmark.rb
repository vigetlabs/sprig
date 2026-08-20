# Plants the matrix benchmark's dataset (see generate_matrix_dataset.rb) through the
# real, public Sprig pipeline against any combination of source format and storage
# system, so the two can be compared independently of each other -- the same
# generated files work unmodified against every storage backend, since
# sprig_record(Klass, id).id resolves at plant time against whichever adapter is
# actually running, not something baked into the file.
#
# Usage:
#   ruby run_matrix_benchmark.rb <dataset-dir> <yml|json|csv> <sqlite|postgres|mongodb>
#
# Wrap with /usr/bin/time -l (macOS) / -v (Linux) for isolated peak-RSS + wall-time
# measurement, one combination per process, same methodology as run_benchmark.rb.
#
# Connection env vars:
#   Postgres: SPRIG_BENCHMARK_PG_{HOST,PORT,USER,PASSWORD,DATABASE}, defaulting to the
#             sprig-benchmark-postgres container on port 5433 (see benchmark/README.md).
#   MongoDB:  SPRIG_BENCHMARK_MONGO_{HOST,PORT,DATABASE}, defaulting to port 27018 --
#             a dedicated sprig-benchmark-mongo container, deliberately separate from
#             the sprig-mongo-test container the spec suite uses (see
#             benchmark/matrix/README.md's setup instructions): that one runs a small
#             tmpfs sized for tiny spec fixtures, not benchmark-scale data, and
#             actually ran out of space and crashed WiredTiger the first time a
#             medium-tier (10K-row) run was pointed at it.
#   SQLite:   SPRIG_BENCHMARK_SQLITE_PATH (defaults to a tmp file, recreated fresh
#             each run -- SQLite's own in-process storage is deliberately part of
#             what this matrix measures, unlike the rest of this benchmark suite,
#             which excludes it precisely because it isn't a separate process)
require "logger"
require "sprig"

dir = ARGV[0]
format = ARGV[1]
storage = ARGV[2]

unless dir && %w[yml json csv].include?(format) && %w[sqlite postgres mongodb].include?(storage)
  raise "usage: run_matrix_benchmark.rb <dataset-dir> <yml|json|csv> <sqlite|postgres|mongodb>"
end

parser = {
  "yml" => Sprig::Parser::Yml,
  "json" => Sprig::Parser::Json,
  "csv" => Sprig::Parser::Csv
}.fetch(format)

Sprig.configure { |c| c.logger = Logger.new(File::NULL) }

case storage
when "sqlite", "postgres"
  require "active_record"
  Sprig.adapter = :active_record

  ActiveRecord::Base.establish_connection(
    if storage == "sqlite"
      path = ENV.fetch("SPRIG_BENCHMARK_SQLITE_PATH", "/tmp/sprig_benchmark_matrix.sqlite3")
      File.delete(path) if File.exist?(path)
      {adapter: "sqlite3", database: path}
    else
      {
        adapter: "postgresql",
        host: ENV.fetch("SPRIG_BENCHMARK_PG_HOST", "localhost"),
        port: ENV.fetch("SPRIG_BENCHMARK_PG_PORT", "5433").to_i,
        user: ENV.fetch("SPRIG_BENCHMARK_PG_USER", "postgres"),
        password: ENV.fetch("SPRIG_BENCHMARK_PG_PASSWORD", "postgres"),
        database: ENV.fetch("SPRIG_BENCHMARK_PG_DATABASE", "sprig_benchmark_matrix")
      }
    end
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
  if storage == "postgres"
    ActiveRecord::Base.connection.execute("TRUNCATE customers, tags, projects, tasks, project_tags")
  end

  class Customer < ActiveRecord::Base; end

  class Tag < ActiveRecord::Base; end

  class Project < ActiveRecord::Base; end

  class Task < ActiveRecord::Base; end

  class ProjectTag < ActiveRecord::Base; end
when "mongodb"
  require "mongoid"
  Sprig.adapter = :mongoid

  Mongoid.configure do |config|
    config.clients.default = {
      hosts: ["#{ENV.fetch("SPRIG_BENCHMARK_MONGO_HOST", "localhost")}:#{ENV.fetch("SPRIG_BENCHMARK_MONGO_PORT", "27018")}"],
      database: ENV.fetch("SPRIG_BENCHMARK_MONGO_DATABASE", "sprig_benchmark_matrix"),
      options: {read: {mode: :primary}}
    }
  end

  class Customer
    include Mongoid::Document

    field :name, type: String
    field :contact_email, type: String
    field :signed_up_on, type: Date
    field :active, type: Boolean
    field :annual_revenue, type: Float
    field :employee_count, type: Integer
    field :notes, type: String
  end

  class Tag
    include Mongoid::Document

    field :name, type: String
    field :category, type: String
  end

  class Project
    include Mongoid::Document

    field :title, type: String
    field :status, type: String
    field :budget, type: Float
    field :starts_on, type: Date
    field :billable, type: Boolean
    field :priority, type: Integer
    field :customer_id, type: BSON::ObjectId
  end

  class Task
    include Mongoid::Document

    field :title, type: String
    field :description, type: String
    field :due_on, type: Date
    field :estimated_hours, type: Float
    field :completed, type: Boolean
    field :assignee_name, type: String
    field :project_id, type: BSON::ObjectId
  end

  class ProjectTag
    include Mongoid::Document

    field :project_id, type: BSON::ObjectId
    field :tag_id, type: BSON::ObjectId
    field :added_on, type: Date
  end

  [Customer, Tag, Project, Task, ProjectTag].each { |klass| klass.delete_all }
end

class Seeder
  include Sprig::Helpers
end

customers_path = File.join(dir, "customers.#{format}")
tags_path = File.join(dir, "tags.#{format}")
projects_path = File.join(dir, "projects.#{format}")
tasks_path = File.join(dir, "tasks.#{format}")
project_tags_path = File.join(dir, "project_tags.#{format}")

directives = [
  {class: ProjectTag, source: File.open(project_tags_path), parser: parser},
  {class: Task, source: File.open(tasks_path), parser: parser},
  {class: Project, source: File.open(projects_path), parser: parser},
  {class: Tag, source: File.open(tags_path), parser: parser},
  {class: Customer, source: File.open(customers_path), parser: parser}
]

Seeder.new.sprig(directives)

warn "planted customers=#{Customer.count} tags=#{Tag.count} projects=#{Project.count} tasks=#{Task.count} project_tags=#{ProjectTag.count}"
