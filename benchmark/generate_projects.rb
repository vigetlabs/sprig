# Generates a YAML seed file of `n` Project records, using Faker for realistic field
# content. Each row is *optionally* linked to a Customer (probability
# `link_probability`, default 0.7) via sprig_record(Customer, ...) -- the rest have no
# customer_id at all, exercising Sprig's handling of a real, but not universal,
# cross-file dependency.
#
# Usage: ruby generate_projects.rb <output-path> <n> <customer_count> [link_probability]
require "faker"

Faker::Config.random = Random.new(43)
srand(43)

n = ARGV[1].to_i
customer_count = ARGV[2].to_i
link_probability = (ARGV[3] || 0.7).to_f
statuses = %w[planned active on_hold completed cancelled]

File.open(ARGV[0], "w") do |f|
  f.puts("records:")
  n.times do |i|
    f.puts("  - sprig_id: #{i}")
    f.puts("    title: #{Faker::Commerce.product_name.inspect}")
    f.puts("    status: #{statuses.sample.inspect}")
    f.puts("    budget: #{Faker::Commerce.price(range: 500..500_000)}")
    f.puts("    starts_on: #{Faker::Date.between(from: "2016-01-01", to: "2026-01-01").to_s.inspect}")
    f.puts("    billable: #{Faker::Boolean.boolean}")
    f.puts("    priority: #{rand(1..5)}")
    if customer_count > 0 && rand < link_probability
      f.puts("    customer_id: \"<%= sprig_record(Customer, #{rand(0...customer_count)}).id %>\"")
    end
  end
end
