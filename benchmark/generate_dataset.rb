# Convenience wrapper: generates all five seed files for one volume in a single
# invocation, with a consistent naming scheme, by shelling out to each dedicated
# generate_*.rb script. Those stay separate, single-purpose files (each independently
# readable/runnable, matching this directory's existing convention) rather than being
# folded into one generator -- this wrapper exists purely to avoid re-deriving the
# right arguments by hand for every volume this benchmark suite measures.
#
# Usage: ruby generate_dataset.rb <output-dir> <n> [tag_count] [rows_per_project]
require "fileutils"

dir = ARGV[0]
n = ARGV[1].to_i
tag_count = ARGV[2] || 20
rows_per_project = ARGV[3] || 2.5
raise "usage: generate_dataset.rb <output-dir> <n> [tag_count] [rows_per_project]" unless dir && n > 0

FileUtils.mkdir_p(dir)
here = File.dirname(__FILE__)

def run(script, *args)
  system(RbConfig.ruby, script, *args.map(&:to_s), exception: true)
end

run(File.join(here, "generate_customers.rb"), File.join(dir, "customers.yml"), n)
run(File.join(here, "generate_tags.rb"), File.join(dir, "tags.yml"), tag_count)
run(File.join(here, "generate_projects.rb"), File.join(dir, "projects.yml"), n, n)
run(File.join(here, "generate_tasks.rb"), File.join(dir, "tasks.yml"), n, n)
run(File.join(here, "generate_project_tags.rb"), File.join(dir, "project_tags.yml"), n, tag_count, rows_per_project)

warn "generated #{dir}/{customers,tags,projects,tasks,project_tags}.yml for n=#{n}"
