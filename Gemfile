source "https://rubygems.org"

gemspec

gem "standardrb", "~> 1.0"

# Used only by benchmark/generate_*.rb to produce realistic fixture data -- not a
# runtime dependency of Sprig itself.
gem "faker"

# Used only by benchmark/run_benchmark.rb, to measure against a real, separate
# PostgreSQL server instead of in-process SQLite (whose own B-tree/buffer memory would
# otherwise be counted alongside Sprig's) -- not a runtime dependency of Sprig itself.
gem "pg"
