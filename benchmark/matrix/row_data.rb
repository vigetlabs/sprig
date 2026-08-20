# Shared row-generation logic for the source/storage matrix benchmark
# (benchmark/matrix/). Reuses the exact same fields, Faker calls, random seeds, and
# relationship shape as the top-level benchmark/generate_*.rb scripts, so the matrix
# benchmark tests the same rich data those do -- just re-serialized into CSV/YAML/JSON
# by generate_matrix_dataset.rb, instead of being tied to one format.
#
# Each method returns a plain Array of String-keyed Hashes (one per row), with any
# sprig_record(...) reference already rendered as the literal ERB string
# ("<%= sprig_record(Klass, id).id %>") -- identical across every storage backend,
# since that expression is evaluated at plant time against whatever adapter is
# actually running, not baked into the generated file.
require "faker"

module Sprig
  module BenchmarkMatrix
    module RowData
      CATEGORIES = %w[priority team type region].freeze
      STATUSES = %w[planned active on_hold completed cancelled].freeze

      def self.customers(n)
        Faker::Config.random = Random.new(42)
        Array.new(n) do |i|
          {
            "sprig_id" => i,
            "name" => Faker::Company.name,
            "contact_email" => Faker::Internet.email,
            "signed_up_on" => Faker::Date.backward(days: 3650).to_s,
            "active" => Faker::Boolean.boolean(true_ratio: 0.8),
            "annual_revenue" => Faker::Commerce.price(range: 1_000..10_000_000),
            "employee_count" => Faker::Number.between(from: 1, to: 50_000),
            "notes" => Faker::Lorem.paragraph(sentence_count: 5)
          }
        end
      end

      def self.tags(count)
        Faker::Config.random = Random.new(45)
        Array.new(count) do |i|
          {
            "sprig_id" => i,
            "name" => Faker::Company.buzzword,
            "category" => CATEGORIES.sample(random: Faker::Config.random)
          }
        end
      end

      def self.projects(n, customer_count, link_probability: 0.7)
        Faker::Config.random = Random.new(43)
        rng = Faker::Config.random
        Array.new(n) do |i|
          row = {
            "sprig_id" => i,
            "title" => Faker::Commerce.product_name,
            "status" => STATUSES.sample(random: rng),
            "budget" => Faker::Commerce.price(range: 500..500_000),
            "starts_on" => Faker::Date.between(from: "2016-01-01", to: "2026-01-01").to_s,
            "billable" => Faker::Boolean.boolean,
            "priority" => rng.rand(1..5)
          }
          if customer_count > 0 && rng.rand < link_probability
            row["customer_id"] = "<%= sprig_record(Customer, #{rng.rand(0...customer_count)}).id %>"
          end
          row
        end
      end

      def self.tasks(n, project_count)
        raise "project_count must be > 0" unless project_count > 0

        Faker::Config.random = Random.new(44)
        rng = Faker::Config.random
        Array.new(n) do |i|
          {
            "sprig_id" => i,
            "title" => Faker::Lorem.sentence,
            "description" => Faker::Lorem.paragraph,
            "due_on" => Faker::Date.forward(days: 180).to_s,
            "estimated_hours" => Faker::Number.decimal(l_digits: 2, r_digits: 1),
            "completed" => Faker::Boolean.boolean,
            "assignee_name" => Faker::Name.name,
            "project_id" => "<%= sprig_record(Project, #{rng.rand(0...project_count)}).id %>"
          }
        end
      end

      def self.project_tags(project_count, tag_count, rows_per_project: 2.5)
        raise "project_count and tag_count must both be > 0" unless project_count > 0 && tag_count > 0

        Faker::Config.random = Random.new(46)
        rng = Faker::Config.random
        count = (project_count * rows_per_project).round
        Array.new(count) do |i|
          {
            "sprig_id" => i,
            "project_id" => "<%= sprig_record(Project, #{rng.rand(0...project_count)}).id %>",
            "tag_id" => "<%= sprig_record(Tag, #{rng.rand(0...tag_count)}).id %>",
            "added_on" => Faker::Date.backward(days: 730).to_s
          }
        end
      end
    end
  end
end
