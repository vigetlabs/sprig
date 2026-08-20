# Generates a YAML seed file of a small, fixed vocabulary of independent Tag records.
# Unlike Customer/Project/Task, this doesn't scale with dataset size -- real tag
# vocabularies stay small regardless of how much data references them, which is exactly
# what makes Tag/ProjectTag a realistic many-to-many: a handful of Tags, each
# referenced by many ProjectTag rows (see generate_project_tags.rb).
#
# Usage: ruby generate_tags.rb <output-path> [count]
require "faker"

Faker::Config.random = Random.new(45)

count = (ARGV[1] || 20).to_i
categories = %w[priority team type region]

File.open(ARGV[0], "w") do |f|
  f.puts("records:")
  count.times do |i|
    f.puts("  - sprig_id: #{i}")
    f.puts("    name: #{Faker::Company.buzzword.inspect}")
    f.puts("    category: #{categories.sample.inspect}")
  end
end
