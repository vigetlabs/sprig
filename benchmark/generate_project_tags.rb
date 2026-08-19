# Generates a YAML seed file of ProjectTag join records -- the many-to-many edge
# between Project and Tag. Every row *always* links to exactly one Project
# (sprig_record(Project, ...)) and one Tag (sprig_record(Tag, ...)), so a ProjectTag
# descriptor always depends on two independent things at once -- unlike every other
# model in this dataset, which depends on at most one. `rows_per_project` controls how
# many ProjectTag rows are generated per project (default 2.5, i.e. each project gets
# on average 2-3 tags).
#
# Usage: ruby generate_project_tags.rb <output-path> <project_count> <tag_count> [rows_per_project]
require "faker"

Faker::Config.random = Random.new(46)
srand(46)

project_count = ARGV[1].to_i
tag_count = ARGV[2].to_i
rows_per_project = (ARGV[3] || 2.5).to_f
raise "project_count and tag_count must both be > 0" unless project_count > 0 && tag_count > 0

count = (project_count * rows_per_project).round

File.open(ARGV[0], "w") do |f|
  f.puts("records:")
  count.times do |i|
    f.puts("  - sprig_id: #{i}")
    f.puts("    project_id: \"<%= sprig_record(Project, #{rand(0...project_count)}).id %>\"")
    f.puts("    tag_id: \"<%= sprig_record(Tag, #{rand(0...tag_count)}).id %>\"")
    f.puts("    added_on: #{Faker::Date.backward(days: 730).to_s.inspect}")
  end
end
