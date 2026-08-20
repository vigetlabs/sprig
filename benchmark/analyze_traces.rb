# DIAGNOSTIC TOOL -- not part of the Sprig library.
#
# Reads the CSV traces and *_final_breakdown.txt snapshots produced by
# instrumented_run.rb and prints the summary numbers cited in benchmark/README.md:
# peak RSS, wall time, and the memory-time integral (storage-space-over-time, in
# MB-seconds) per branch/tier (with percentage deltas against part-1 and against
# the previous stage), plus the "Deep dive" section's per-item/retention numbers.
# This is what turned the raw traces into the README's tables and prose --
# re-running it against the same raw-data directory reproduces those numbers
# exactly; pointing it at a fresh set of traces re-derives them for a new run.
#
# Usage:
#   ruby benchmark/analyze_traces.rb [raw-data-dir] [part-count]
#
# Expects <raw-data-dir>/part-N/{small,medium,large}.csv (and, optionally,
# part-N/{small,medium,large}_final_breakdown.txt), one N per stack position,
# 1..[part-count] (default 7). Missing files are skipped with a note, not an error --
# useful while a batch of runs is still in progress.
require "csv"

raw_dir = ARGV[0] || File.expand_path("~/sprig-benchmark-v3-raw")
part_count = (ARGV[1] || "7").to_i

def read_csv(path)
  return nil unless File.exist?(path)
  rows = CSV.read(path, headers: true).map(&:to_h)
  rows.empty? ? nil : rows
end

def read_breakdown(path)
  return {} unless File.exist?(path)
  text = File.read(path)
  pairs = text.scan(/(\w+)=(-?[\d.]+)?/)
  pairs.each_with_object({}) { |(k, v), h| h[k] = v }
end

def peak_rss_mb(rows)
  rows.map { |r| r["rss_kb"].to_i }.max / 1024.0
end

def last_non_blank(rows, key)
  rows.reverse_each do |r|
    v = r[key]
    return v if v && !v.empty?
  end
  nil
end

def pct(from, to)
  return nil if from.nil? || to.nil? || from.zero?
  ((to - from) / from * 100).round(1)
end

puts "=" * 70
puts "Peak RSS and wall time by branch/tier"
puts "=" * 70

%w[small medium large].each do |tier|
  puts "\n--- #{tier} ---"
  peaks = {}
  (1..part_count).each do |p|
    rows = read_csv(File.join(raw_dir, "part-#{p}", "#{tier}.csv"))
    unless rows
      puts "part-#{p}: (no data)"
      next
    end
    peak = peak_rss_mb(rows)
    wall = rows.last["t"]
    peaks[p] = peak
    baseline_delta = pct(peaks[1], peak) if peaks[1] && p != 1
    prev_delta = pct(peaks[p - 1], peak) if peaks[p - 1] && p > 2
    line = "part-#{p}: peak=#{peak.round(1)}MB wall=#{wall}s"
    line += " (vs part-1 baseline: #{baseline_delta}%)" if baseline_delta
    line += " (vs previous part-#{p - 1}: #{prev_delta}%)" if prev_delta
    puts line
  end
end

puts "\n#{"=" * 70}"
puts "Storage-space-over-time (memory-time integral, MB-seconds) by branch/tier"
puts "=" * 70

%w[small medium large].each do |tier|
  puts "\n--- #{tier} ---"
  values = {}
  (1..part_count).each do |p|
    breakdown = read_breakdown(File.join(raw_dir, "part-#{p}", "#{tier}_final_breakdown.txt"))
    mb_s = breakdown["memory_mb_seconds"]
    unless mb_s
      puts "part-#{p}: (no data)"
      next
    end
    mb_s = mb_s.to_f
    values[p] = mb_s
    baseline_delta = pct(values[1], mb_s) if values[1] && p != 1
    prev_delta = pct(values[p - 1], mb_s) if values[p - 1] && p > 2
    line = "part-#{p}: #{mb_s.round(1)} MB*s"
    line += " (vs part-1 baseline: #{baseline_delta}%)" if baseline_delta
    line += " (vs previous part-#{p - 1}: #{prev_delta}%)" if prev_delta
    puts line
  end
end

puts "\n#{"=" * 70}"
puts "Deep dive: per-item retained-structure costs (medium tier, in-run samples)"
puts "=" * 70

(1..part_count).each do |p|
  rows = read_csv(File.join(raw_dir, "part-#{p}", "medium.csv"))
  next unless rows

  dep_series = rows.map { |r| r["dependency_count"] }.compact.reject(&:empty?).map(&:to_i)
  sorted_len = last_non_blank(rows, "sorted_seeds_len")
  sorted_bytes = last_non_blank(rows, "sorted_seeds_bytes_est")
  waiting_lens = rows.map { |r| r["waiting_len"] }.compact.reject(&:empty?).map(&:to_i)

  parts = ["part-#{p}:"]
  parts << "dependency_count first=#{dep_series.first} max=#{dep_series.max} last=#{dep_series.last}" unless dep_series.empty?
  if sorted_len && sorted_len.to_i > 0
    per_item = (sorted_bytes.to_f / sorted_len.to_i).round
    parts << "retained_array len=#{sorted_len} per_item_bytes=#{per_item}"
  end
  parts << "waiting_len max=#{waiting_lens.max}" unless waiting_lens.empty?
  puts parts.join("  ") if parts.size > 1
end

puts "\n#{"=" * 70}"
puts "Final post-run breakdown (forced-GC-verified where available)"
puts "=" * 70

%w[small medium large].each do |tier|
  (1..part_count).each do |p|
    path = File.join(raw_dir, "part-#{p}", "#{tier}_final_breakdown.txt")
    next unless File.exist?(path)
    puts "\n-- part-#{p} #{tier} --"
    puts File.read(path)
  end
end
