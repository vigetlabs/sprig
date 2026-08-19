# Generates a YAML seed file of `n` Task records, using Faker for realistic field
# content. Every row is *always* linked to a Project via sprig_record(Project, ...) --
# the required-dependency counterpart to Project's optional link to Customer.
#
# Usage: ruby generate_tasks.rb <output-path> <n> <project_count>
require "faker"

Faker::Config.random = Random.new(44)
srand(44)

n = ARGV[1].to_i
project_count = ARGV[2].to_i
raise "project_count must be > 0" unless project_count > 0

File.open(ARGV[0], "w") do |f|
  f.puts("records:")
  n.times do |i|
    f.puts("  - sprig_id: #{i}")
    f.puts("    title: #{Faker::Lorem.sentence.inspect}")
    f.puts("    description: #{Faker::Lorem.paragraph.inspect}")
    f.puts("    due_on: #{Faker::Date.forward(days: 180).to_s.inspect}")
    f.puts("    estimated_hours: #{Faker::Number.decimal(l_digits: 2, r_digits: 1)}")
    f.puts("    completed: #{Faker::Boolean.boolean}")
    f.puts("    assignee_name: #{Faker::Name.name.inspect}")
    f.puts("    project_id: \"<%= sprig_record(Project, #{rand(0...project_count)}).id %>\"")
  end
end
