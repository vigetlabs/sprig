require "rspec/core/rake_task"
require "standard/rake"
require "appraisal"

RSpec::Core::RakeTask.new(:spec)

task default: :spec

namespace :coverage do
  desc "Run the spec suite against every Appraisal gemfile and aggregate coverage into one report"
  task :aggregate do
    sh "bundle exec appraisal install"
    rm_rf "coverage"

    appraisals = `bundle exec appraisal list`.split("\n").reject(&:empty?)

    appraisals.each do |appraisal|
      sh "bundle exec appraisal #{appraisal} rspec"
    end

    puts "Aggregated coverage report: file://#{File.expand_path("coverage/index.html")}"
  end
end
