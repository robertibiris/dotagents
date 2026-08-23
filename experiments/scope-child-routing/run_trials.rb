#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "json"
require "open3"
require "optparse"
require "pathname"
require "thread"
require "time"
require "yaml"

options = { jobs: 3, model: "gpt-5.6-luna", repeats: 1, seed: 20_260_822, ids: nil }
OptionParser.new do |parser|
  parser.on("--fixtures DIR") { |value| options[:fixtures] = value }
  parser.on("--output DIR") { |value| options[:output] = value }
  parser.on("--jobs N", Integer) { |value| options[:jobs] = value }
  parser.on("--model MODEL") { |value| options[:model] = value }
  parser.on("--repeats N", Integer) { |value| options[:repeats] = value }
  parser.on("--seed N", Integer) { |value| options[:seed] = value }
  parser.on("--ids x,y,z", Array) { |value| options[:ids] = value }
end.parse!

abort "--fixtures and --output are required" unless options[:fixtures] && options[:output]
abort "--jobs and --repeats must be positive" unless options[:jobs].positive? && options[:repeats].positive?

experiment_dir = Pathname(__dir__)
config = YAML.safe_load((experiment_dir / "experiment.yml").read, aliases: false)
fixtures = Pathname(options[:fixtures]).expand_path
output = Pathname(options[:output]).expand_path
abort "missing fixtures: #{fixtures}" unless fixtures.directory?
abort "output already exists: #{output}" if output.exist?

FileUtils.mkdir_p(output / "raw")
prompts = config.fetch("prompts")
prompts = prompts.select { |prompt| options[:ids].include?(prompt.fetch("id")) } if options[:ids]
abort "no prompts selected" if prompts.empty?

trials = []
options[:repeats].times do |repeat|
  config.fetch("variants").keys.each do |fixture_name|
    prompts.each do |prompt|
      trials << { "fixture" => fixture_name, "repeat" => repeat + 1, "prompt" => prompt }
    end
  end
end
trials.shuffle!(random: Random.new(options[:seed]))

def parse_events(stdout)
  stdout.each_line.each_with_object([]) do |line, parsed|
    parsed << JSON.parse(line)
  rescue JSON::ParserError
    next
  end
end

def find_usage(events)
  completed = events.reverse.find { |event| event["type"] == "turn.completed" }
  usage = completed && completed["usage"]
  return usage if usage.is_a?(Hash)

  events.reverse_each do |event|
    stack = [event]
    until stack.empty?
      value = stack.pop
      next unless value.is_a?(Hash) || value.is_a?(Array)
      if value.is_a?(Hash)
        candidate = value["usage"]
        return candidate if candidate.is_a?(Hash) && candidate.key?("total_tokens")
        stack.concat(value.values)
      else
        stack.concat(value)
      end
    end
  end
  {}
end

def normalized_usage(usage)
  normalized = usage.dup
  input = normalized["input_tokens"] || 0
  output = normalized["output_tokens"] || 0
  cached = normalized["cached_input_tokens"] || 0
  normalized["uncached_input_tokens"] = input - cached
  normalized["total_tokens"] ||= input + output
  normalized
end

def agent_message(events)
  items = events.reverse.each_with_object([]) do |event, selected|
    selected << event["item"] if event["type"] == "item.completed" && event["item"]
  end
  item = items.find { |candidate| candidate["type"] == "agent_message" }
  item && (item["text"] || item["content"])
end

def parse_decision(message)
  return nil unless message.is_a?(String)
  JSON.parse(message)
rescue JSON::ParserError
  opening = message.index("{")
  closing = message.rindex("}")
  return nil unless opening && closing && closing > opening
  JSON.parse(message[opening..closing])
rescue JSON::ParserError
  nil
end

def expected_verifications(expected)
  expected.flat_map do |route|
    pieces = route.split("/")
    pieces.each_index.map { |index| "#{pieces[0..index].join('/')}/AGENTS.md" }
  end.uniq.sort
end

def score(prompt, decision)
  return { "routing_correct" => false, "verification_correct" => false } unless decision.is_a?(Hash)

  expected = prompt.fetch("expected").sort
  selected = Array(decision["selected"]).sort
  expected_decision = case prompt.fetch("category")
                      when "root-only" then "root"
                      when "no-match" then "none"
                      when "ambiguous" then "clarification_required"
                      else "selected"
                      end
  expected_verified = expected_verifications(expected)
  verified = Array(decision["verified"]).sort
  verification_correct = (expected_verified - verified).empty?
  verification_correct &&= verified.empty? if prompt.fetch("category") == "root-only"
  {
    "routing_correct" => decision["decision"] == expected_decision && selected == expected,
    "verification_correct" => verification_correct,
    "expected_decision" => expected_decision,
    "expected_verified" => expected_verified,
    "extra_verified" => verified - expected_verified
  }
end

queue = Queue.new
trials.each_with_index { |trial, index| queue << trial.merge("sequence" => index + 1) }
results = []
mutex = Mutex.new

workers = options[:jobs].times.map do
  Thread.new do
    loop do
      trial = queue.pop(true)
      prompt = trial.fetch("prompt")
      trial_id = format("%03d-%s-r%d-%s", trial.fetch("sequence"), prompt.fetch("id"), trial.fetch("repeat"), trial.fetch("fixture"))
      fixture = fixtures / trial.fetch("fixture")
      user_prompt = <<~PROMPT
        Resolve the most appropriate registered scope or scopes for the request below. Do not perform the requested domain work. Follow this workspace's routing instructions and return only the required structured result.

        Request: #{prompt.fetch('request')}
      PROMPT
      command = [
        "codex", "exec", "--json", "--ephemeral", "--ignore-user-config",
        "-s", "read-only", "-C", fixture.to_s, "-m", options[:model],
        "--output-schema", (experiment_dir / "result.schema.json").to_s, "-"
      ]
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      stdout, stderr, status = Open3.capture3(*command, stdin_data: user_prompt)
      duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
      events = parse_events(stdout)
      message = agent_message(events)
      decision = parse_decision(message)
      command_items_by_id = events.each_with_object({}) do |event, selected|
        item = event["item"] if event["type"] == "item.completed"
        item ||= event["item"] if event["type"] == "item.started"
        selected[item["id"]] = item if item && item["type"] == "command_execution"
      end
      command_items = command_items_by_id.values
      scored = score(prompt, decision)
      result = {
        "trial_id" => trial_id,
        "fixture" => trial.fetch("fixture"),
        "repeat" => trial.fetch("repeat"),
        "prompt_id" => prompt.fetch("id"),
        "category" => prompt.fetch("category"),
        "request" => prompt.fetch("request"),
        "expected" => prompt.fetch("expected"),
        "decision" => decision,
        "routing_correct" => scored.fetch("routing_correct"),
        "verification_correct" => scored.fetch("verification_correct"),
        "expected_decision" => scored["expected_decision"],
        "expected_verified" => scored["expected_verified"],
        "extra_verified" => scored["extra_verified"],
        "body_sentinel_seen" => (stdout + stderr).include?("BODY_SENTINEL_"),
        "command_count" => command_items.length,
        "commands" => command_items.map { |item| item["command"] },
        "usage" => normalized_usage(find_usage(events)),
        "duration_seconds" => duration.round(3),
        "exit_status" => status.exitstatus,
        "stderr" => stderr
      }
      (output / "raw" / "#{trial_id}.jsonl").write(stdout)
      (output / "raw" / "#{trial_id}.stderr.txt").write(stderr) unless stderr.empty?
      mutex.synchronize do
        results << result
        puts JSON.generate(result.slice("trial_id", "routing_correct", "verification_correct", "body_sentinel_seen", "exit_status", "usage"))
      end
    rescue ThreadError
      break
    end
  end
end
workers.each(&:join)

results.sort_by! { |result| result.fetch("trial_id") }
(output / "results.json").write(JSON.pretty_generate({
  "generated_at" => Time.now.iso8601,
  "model" => options[:model],
  "seed" => options[:seed],
  "repeats" => options[:repeats],
  "results" => results
}) + "\n")
(output / "results.jsonl").write(results.map { |result| JSON.generate(result) }.join("\n") + "\n")
puts "results: #{output}"
