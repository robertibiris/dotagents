#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "optparse"
require "pathname"
require "yaml"

options = {}
OptionParser.new do |parser|
  parser.on("--output DIR") { |value| options[:output] = value }
end.parse!

abort "usage: generate_fixtures.rb --output DIR" unless options[:output]

experiment_dir = Pathname(__dir__)
config = YAML.safe_load((experiment_dir / "experiment.yml").read, aliases: false)
output = Pathname(options[:output]).expand_path
abort "output already exists: #{output}" if output.exist?

FileUtils.mkdir_p(output)

header_tool = <<~'RUBY'
  #!/usr/bin/env ruby
  # frozen_string_literal: true

  require "pathname"

  abort "usage: inspect_header.rb RELATIVE_AGENTS_PATH [...]" if ARGV.empty?
  git_root = `git rev-parse --show-toplevel`.strip
  abort "cannot resolve portfolio root" if git_root.empty?
  root = Pathname(git_root).realpath

  ARGV.each do |argument|
    requested = Pathname(argument)
    abort "path must be relative" if requested.absolute?
    target = (root / requested).cleanpath
    abort "target escapes workspace" unless target.to_s.start_with?("#{root}/")
    abort "target must be AGENTS.md" unless target.basename.to_s == "AGENTS.md"
    abort "missing target: #{requested}" unless target.file?

    lines = []
    File.foreach(target) do |line|
      lines << line
      break if lines.length > 1 && line.chomp == "---"
    end
    abort "invalid frontmatter: #{requested}" unless lines.first&.chomp == "---" && lines.last&.chomp == "---"
    puts "=== #{requested} ==="
    print lines.join
  end
RUBY

routing_body = <<~'MARKDOWN'
  # Portfolio Routing Map

  This scope is a routing entry point. For each request, decide whether it belongs at this scope, at no registered scope, or in one or more registered child scopes.

  - Do not perform the requested domain work; return only the routing decision required by the response schema.
  - Treat only `children` entries in this file's frontmatter as registered direct routes.
  - Use routing metadata already present in an entry before inspecting child metadata.
  - When routing metadata is insufficient, inspect registered child headers as needed rather than guessing.
  - Verify every selected direct child with `ruby "$(git rev-parse --show-toplevel)/.agents/tools/inspect_header.rb" CHILD/AGENTS.md`, passing paths relative to the portfolio root.
  - That exact header-inspector command is the only permitted way to read another scope map during routing. Do not search for other tools or enumerate files.
  - The inspector accepts several registered map paths in one call. When broad metadata inspection is necessary, batch the smallest defensible candidate set into one call.
  - Run header inspection from the portfolio Git root and do not change the command working directory during routing.
  - Never read text after a scope map's closing frontmatter delimiter.
  - Do not inspect unregistered directories or unrelated child bodies.
  - For a nested target, verify each selected hop and continue using only that verified map's registered children.
  - For genuine ambiguity, verify the plausible candidates, choose `clarification_required`, and list those candidate paths in `selected`.
  - Use `root` when the request concerns this portfolio entry point itself. Use `none` when no registered child applies.
  - Report final target paths relative to this portfolio root. For a nested route, report only the final leaf in `selected` and every inspected hop in `verified`.
  - In `selected`, use scope paths without `/AGENTS.md` (for example `billing` or `content/review`). In `verified`, use map paths including `/AGENTS.md`.
MARKDOWN

def serialized_children(entries, hinted:)
  entries.map do |entry|
    path = "#{entry.fetch('path')}/AGENTS.md"
    hinted ? { "path" => path, "when" => entry.fetch("when") } : path
  end
end

def write_scope(path, name:, description:, children:, body:)
  data = {
    "name" => name,
    "description" => description,
    "children" => children,
    "resources" => { "context" => [], "skills" => [] }
  }
  path.dirname.mkpath
  path.write("---\n#{YAML.dump(data).sub(/\A---\s*\n/, '')}---\n\n#{body}")
end

config.fetch("variants").each do |fixture_name, semantic_name|
  hinted = semantic_name == "path-with-routing-hints"
  root = output / fixture_name
  FileUtils.mkdir_p(root / ".agents/tools")
  (root / ".agents/tools/inspect_header.rb").write(header_tool)
  FileUtils.chmod(0o755, root / ".agents/tools/inspect_header.rb")

  write_scope(
    root / "AGENTS.md",
    name: "routing-portfolio",
    description: "Entry scope for routing work to one of twenty independently usable child scopes.",
    children: serialized_children(config.fetch("children"), hinted: hinted),
    body: routing_body
  )

  config.fetch("children").each do |child|
    child_name = child.fetch("path")
    nested = config.fetch("nested").fetch(child_name, [])
    write_scope(
      root / child_name / "AGENTS.md",
      name: child_name,
      description: child.fetch("description"),
      children: serialized_children(nested, hinted: hinted),
      body: "# Child Scope\n\nBODY_SENTINEL_#{child_name.upcase}: this body must never be read during routing.\n"
    )

    nested.each do |leaf|
      leaf_path = "#{child_name}/#{leaf.fetch('path')}"
      write_scope(
        root / leaf_path / "AGENTS.md",
        name: leaf_path.tr("/", "-"),
        description: leaf.fetch("description"),
        children: [],
        body: "# Nested Child Scope\n\nBODY_SENTINEL_#{leaf_path.upcase.tr('/', '_')}: this body must never be read during routing.\n"
      )
    end
  end

  system("git", "init", "-q", root.to_s, exception: true)
end

(output / "fixture-map.yml").write(YAML.dump(config.fetch("variants")))
puts output
