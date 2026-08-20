# Generates one format's worth of the source/storage matrix benchmark's dataset --
# the same Customer/Tag/Project/Task/ProjectTag shape, volumes, and relationships as
# the top-level benchmark/generate_dataset.rb, serialized as CSV, YAML, or JSON
# (chosen by output file extension) instead of being tied to YAML only. See
# row_data.rb for the shared generation logic and writers.rb for the per-format
# serialization.
#
# Usage:
#   ruby generate_matrix_dataset.rb <output-dir> <n> <format> [tag_count] [rows_per_project]
#
# <format> is one of: yml, json, csv
# Writes <output-dir>/{customers,tags,projects,tasks,project_tags}.<format>
require "fileutils"
require_relative "row_data"
require_relative "writers"

dir = ARGV[0]
n = ARGV[1].to_i
format = ARGV[2]
tag_count = (ARGV[3] || 20).to_i
rows_per_project = (ARGV[4] || 2.5).to_f

unless dir && n > 0 && %w[yml json csv].include?(format)
  raise "usage: generate_matrix_dataset.rb <output-dir> <n> <yml|json|csv> [tag_count] [rows_per_project]"
end

FileUtils.mkdir_p(dir)

RowData = Sprig::BenchmarkMatrix::RowData
Writers = Sprig::BenchmarkMatrix::Writers

Writers.write(File.join(dir, "customers.#{format}"), RowData.customers(n))
Writers.write(File.join(dir, "tags.#{format}"), RowData.tags(tag_count))
Writers.write(File.join(dir, "projects.#{format}"), RowData.projects(n, n))
Writers.write(File.join(dir, "tasks.#{format}"), RowData.tasks(n, n))
Writers.write(File.join(dir, "project_tags.#{format}"), RowData.project_tags(n, tag_count, rows_per_project: rows_per_project))

warn "generated #{dir}/{customers,tags,projects,tasks,project_tags}.#{format} for n=#{n}"
