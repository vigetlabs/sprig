# Generates a YAML seed file of `n` independent Customer records (no dependencies),
# using Faker for realistic field content across a mix of data types (string, date,
# boolean, decimal, integer, text).
#
# Usage: ruby generate_customers.rb <output-path> <n>
require "faker"

Faker::Config.random = Random.new(42)

File.open(ARGV[0], "w") do |f|
  f.puts("records:")
  ARGV[1].to_i.times do |i|
    f.puts("  - sprig_id: #{i}")
    f.puts("    name: #{Faker::Company.name.inspect}")
    f.puts("    contact_email: #{Faker::Internet.email.inspect}")
    f.puts("    signed_up_on: #{Faker::Date.backward(days: 3650).to_s.inspect}")
    f.puts("    active: #{Faker::Boolean.boolean(true_ratio: 0.8)}")
    f.puts("    annual_revenue: #{Faker::Commerce.price(range: 1_000..10_000_000)}")
    f.puts("    employee_count: #{Faker::Number.between(from: 1, to: 50_000)}")
    f.puts("    notes: #{Faker::Lorem.paragraph(sentence_count: 5).inspect}")
  end
end
