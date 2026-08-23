#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "optparse"
require "pathname"
require "yaml"

options = {}
OptionParser.new do |parser|
  parser.on("--results FILE") { |value| options[:results] = value }
  parser.on("--output FILE") { |value| options[:output] = value }
end.parse!
abort "--results and --output are required" unless options[:results] && options[:output]

experiment = YAML.safe_load((Pathname(__dir__) / "experiment.yml").read, aliases: false)
variant_names = experiment.fetch("variants")
results = JSON.parse(Pathname(options[:results]).read).fetch("results")

def expected_verifications(expected)
  expected.flat_map do |route|
    pieces = route.split("/")
    pieces.each_index.map { |index| "#{pieces[0..index].join('/')}/AGENTS.md" }
  end.uniq.sort
end

results.each do |row|
  expected_verified = expected_verifications(row.fetch("expected"))
  verified = Array(row.dig("decision", "verified")).sort
  verification_correct = (expected_verified - verified).empty?
  verification_correct &&= verified.empty? if row["category"] == "root-only"
  row["verification_correct"] = verification_correct
  row["expected_verified"] = expected_verified
  row["extra_verified"] = verified - expected_verified
end

def percentile(values, fraction)
  return nil if values.empty?
  sorted = values.sort
  sorted[((sorted.length - 1) * fraction).round]
end

def metrics(rows)
  compliant = rows.select do |row|
    row["routing_correct"] && row["verification_correct"] && !row["body_sentinel_seen"] && row["exit_status"].zero?
  end
  totals = rows.map { |row| row.dig("usage", "total_tokens") || 0 }
  inputs = rows.map { |row| row.dig("usage", "input_tokens") || 0 }
  uncached = rows.map { |row| row.dig("usage", "uncached_input_tokens") || 0 }
  cached = rows.map { |row| row.dig("usage", "cached_input_tokens") || 0 }
  outputs = rows.map { |row| row.dig("usage", "output_tokens") || 0 }
  {
    "trials" => rows.length,
    "routing_correct" => rows.count { |row| row["routing_correct"] },
    "verification_correct" => rows.count { |row| row["verification_correct"] },
    "compliant" => compliant.length,
    "body_sentinel_exposures" => rows.count { |row| row["body_sentinel_seen"] },
    "token_totals" => {
      "input" => inputs.sum,
      "cached_input" => cached.sum,
      "uncached_input" => uncached.sum,
      "output" => outputs.sum,
      "total" => totals.sum
    },
    "total_tokens_median" => percentile(totals, 0.5),
    "total_tokens_p95" => percentile(totals, 0.95),
    "tokens_per_compliant_route" => compliant.empty? ? nil : (totals.sum.to_f / compliant.length).round(1),
    "commands_total" => rows.sum { |row| row["command_count"] || 0 },
    "commands_median" => percentile(rows.map { |row| row["command_count"] || 0 }, 0.5),
    "duration_seconds_total" => rows.sum { |row| row["duration_seconds"] || 0 }.round(3),
    "duration_seconds_median" => percentile(rows.map { |row| row["duration_seconds"] || 0 }, 0.5)
  }
end

summary = {
  "overall" => {},
  "by_category" => {},
  "paired_total_token_difference_hint_minus_path" => {}
}

variant_names.each do |fixture, semantic_name|
  variant_rows = results.select { |row| row["fixture"] == fixture }
  summary["overall"][semantic_name] = metrics(variant_rows)
  summary["by_category"][semantic_name] = variant_rows.group_by { |row| row["category"] }
                                                       .transform_values { |rows| metrics(rows) }
end

path_fixture = variant_names.key("path-only")
hint_fixture = variant_names.key("path-with-routing-hints")
paired_differences = results.group_by { |row| [row["prompt_id"], row["repeat"]] }.each_with_object([]) do |(_key, rows), differences|
  path = rows.find { |row| row["fixture"] == path_fixture }
  hint = rows.find { |row| row["fixture"] == hint_fixture }
  next unless path && hint
  differences << (hint.dig("usage", "total_tokens") || 0) - (path.dig("usage", "total_tokens") || 0)
end
summary["paired_total_token_difference_hint_minus_path"] = {
  "count" => paired_differences.length,
  "sum" => paired_differences.sum,
  "median" => percentile(paired_differences, 0.5),
  "p95" => percentile(paired_differences, 0.95),
  "hint_cheaper_pairs" => paired_differences.count(&:negative?),
  "path_cheaper_pairs" => paired_differences.count(&:positive?),
  "ties" => paired_differences.count(&:zero?)
}

Pathname(options[:output]).write(JSON.pretty_generate(summary) + "\n")
puts JSON.pretty_generate(summary)
