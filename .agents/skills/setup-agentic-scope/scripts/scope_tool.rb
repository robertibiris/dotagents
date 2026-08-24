#!/usr/bin/env ruby

require "fileutils"
require "json"
require "optparse"
require "pathname"
require "tempfile"
require "yaml"

module AgenticScope
  MAX_FRONTMATTER_BYTES = 65_536
  REQUIRED_SCOPE_KEYS = %w[name description].freeze
  REQUIRED_RESOURCE_KEYS = %w[name description].freeze
  HELP = <<~TEXT.freeze
    Usage: scope_tool.rb COMMAND [options]

    Commands:
      setup       Create or repair an independently usable scope
      register-child  Register or update one direct child on a parent scope
      resolve     Resolve a standalone scope or an explicit composed route
      inspect     Read registered scope and resource metadata without bodies
      candidates  Report direct-child candidates under explicit containers
      adapters    Generate, repair, or check thin platform adapters
      validate    Validate schema, descendant routes, resources, and skill names

    Run scope_tool.rb COMMAND --help for command-specific options.
  TEXT

  class ToolError < StandardError; end

  module_function

  def absolute(path, base = Dir.pwd)
    File.expand_path(path, base)
  end

  def scope_map_path(path, base = Dir.pwd)
    candidate = absolute(path, base)
    File.directory?(candidate) ? File.join(candidate, "AGENTS.md") : candidate
  end

  def relative_path(target, from_directory)
    Pathname.new(target).relative_path_from(Pathname.new(from_directory)).to_s
  rescue ArgumentError
    target
  end

  def read_frontmatter(path, include_body: false)
    raise ToolError, "File is not readable: #{path}" unless File.file?(path) && File.readable?(path)

    header_lines = []
    bytes = 0
    body = nil

    File.open(path, "rb") do |file|
      first = file.gets
      raise ToolError, "Missing opening frontmatter delimiter: #{path}" unless first&.chomp == "---"
      bytes += first.bytesize
      closed = false

      while (line = file.gets)
        bytes += line.bytesize
        raise ToolError, "Frontmatter exceeds #{MAX_FRONTMATTER_BYTES} bytes: #{path}" if bytes > MAX_FRONTMATTER_BYTES

        if line.chomp == "---"
          closed = true
          break
        end
        header_lines << line
      end

      raise ToolError, "Missing closing frontmatter delimiter: #{path}" unless closed
      body = file.read if include_body
    end

    yaml = header_lines.join.force_encoding("UTF-8")
    data = YAML.safe_load(yaml, permitted_classes: [], permitted_symbols: [], aliases: false)
    raise ToolError, "Frontmatter must be a mapping: #{path}" unless data.is_a?(Hash)
    [stringify_keys(data), body]
  rescue Psych::Exception => e
    raise ToolError, "Invalid YAML frontmatter in #{path}: #{e.message}"
  end

  def stringify_keys(value)
    case value
    when Hash
      value.each_with_object({}) { |(key, nested), output| output[key.to_s] = stringify_keys(nested) }
    when Array
      value.map { |nested| stringify_keys(nested) }
    else
      value
    end
  end

  def validate_resource_header!(data, path)
    REQUIRED_RESOURCE_KEYS.each do |key|
      value = data[key]
      raise ToolError, "Missing or empty '#{key}' in #{path}" unless value.is_a?(String) && !value.strip.empty?
    end
  end

  def validate_scope_header!(data, path)
    REQUIRED_SCOPE_KEYS.each { |key| raise ToolError, "Missing '#{key}' in #{path}" unless data.key?(key) }
    validate_resource_header!(data, path)
    if data.key?("scope")
      raise ToolError, "Legacy 'scope' mapping is unsupported in #{path}; migrate type/confidential to top-level fields and replace parent/children with one-way child entries"
    end

    unless data["type"].nil? || (data["type"].is_a?(String) && !data["type"].strip.empty?)
      raise ToolError, "'type' must be a non-empty string in #{path}"
    end
    unless data["confidential"].nil? || data["confidential"] == true || data["confidential"] == false
      raise ToolError, "'confidential' must be true or false in #{path}"
    end
    children = data.fetch("children", [])
    raise ToolError, "'children' must be an array in #{path}" unless children.is_a?(Array)
    seen_paths = {}
    children.each_with_index do |child, index|
      raise ToolError, "'children[#{index}]' must be a mapping in #{path}" unless child.is_a?(Hash)
      %w[path when].each do |key|
        value = child[key]
        raise ToolError, "Missing or empty 'children[#{index}].#{key}' in #{path}" unless value.is_a?(String) && !value.strip.empty?
      end
      raise ToolError, "Duplicate child path '#{child['path']}' in #{path}" if seen_paths[child["path"]]
      unless File.basename(child["path"]) == "AGENTS.md"
        raise ToolError, "'children[#{index}].path' must point to AGENTS.md in #{path}"
      end
      seen_paths[child["path"]] = true
    end

    resources = data.fetch("resources", {})
    raise ToolError, "'resources' must be a mapping in #{path}" unless resources.is_a?(Hash)
    %w[context skills].each do |key|
      value = resources.fetch(key, [])
      raise ToolError, "'resources.#{key}' must be an array in #{path}" unless value.is_a?(Array)
      seen_resources = {}
      value.each_with_index do |declared, index|
        unless declared.is_a?(String) && !declared.strip.empty?
          raise ToolError, "'resources.#{key}[#{index}]' must be a non-empty path string in #{path}"
        end
        raise ToolError, "Duplicate resource path '#{declared}' in resources.#{key} of #{path}" if seen_resources[declared]
        seen_resources[declared] = true
      end
    end
  end

  def child_entries(data)
    data.fetch("children", [])
  end

  def resource_paths(data, kind)
    data.fetch("resources", {}).fetch(kind, [])
  end

  def resolve_declared(declaring_map, declared_path)
    absolute(declared_path, File.dirname(declaring_map))
  end

  def metadata_record(kind:, data:, declared_by:, declared_path:, resolved_path:)
    {
      "kind" => kind,
      "name" => data["name"],
      "description" => data["description"],
      "declared_by" => declared_by,
      "declared_path" => declared_path,
      "resolved_path" => resolved_path,
      "body_loaded" => false
    }
  end

  def scope_record(path, declared_by: nil, declared_path: nil)
    data, = read_frontmatter(path)
    validate_scope_header!(data, path)
    metadata_record(
      kind: "scope",
      data: data,
      declared_by: declared_by || path,
      declared_path: declared_path || File.basename(path),
      resolved_path: path
    ).merge("scope_type" => data["type"])
  end

  def deduplicate_records(records)
    seen = {}
    records.select do |record|
      key = [record["kind"], record["resolved_path"]]
      next false if seen[key]
      seen[key] = true
    end
  end

  def inspect_scope(map_path, includes)
    map_path = scope_map_path(map_path)
    data, = read_frontmatter(map_path)
    validate_scope_header!(data, map_path)
    records = []

    records << scope_record(map_path) if includes.include?("map")

    if includes.include?("resources")
      { "context" => resource_paths(data, "context"), "skill" => resource_paths(data, "skills") }.each do |kind, paths|
        paths.each do |declared_path|
          resolved = resolve_declared(map_path, declared_path)
          resource_data, = read_frontmatter(resolved)
          validate_resource_header!(resource_data, resolved)
          records << metadata_record(
            kind: kind,
            data: resource_data,
            declared_by: map_path,
            declared_path: declared_path,
            resolved_path: resolved
          )
        end
      end
    end

    if includes.include?("children")
      child_entries(data).each do |child|
        declared = child.fetch("path")
        resolved = resolve_declared(map_path, declared)
        records << scope_record(resolved, declared_by: map_path, declared_path: declared)
          .merge("routing_hint" => child.fetch("when"))
      end
    end

    { "records" => deduplicate_records(records), "boundaries" => [] }
  end

  def nearest_scope_map(start_path)
    current = File.directory?(start_path) ? absolute(start_path) : File.dirname(absolute(start_path))
    loop do
      candidate = File.join(current, "AGENTS.md")
      return candidate if File.file?(candidate) && File.readable?(candidate)
      parent = File.dirname(current)
      break if parent == current
      current = parent
    end
    raise ToolError, "No readable AGENTS.md found at or above: #{start_path}"
  end

  def composed_route(entry_map, target_path)
    target = File.directory?(target_path) ? absolute(target_path) : File.dirname(absolute(target_path))
    route = []
    current = scope_map_path(entry_map)
    visited = {}

    loop do
      raise ToolError, "Child-registration cycle detected at #{current}" if visited[current]
      visited[current] = true
      data, = read_frontmatter(current)
      validate_scope_header!(data, current)
      current_dir = File.dirname(current)
      unless path_within?(target, current_dir)
        raise ToolError, "Target #{target} is outside the composed entry scope #{entry_map}"
      end
      route << scope_record(current)
      matching = child_entries(data).select do |child|
        child_map = resolve_declared(current, child.fetch("path"))
        path_within?(target, File.dirname(child_map))
      end
      raise ToolError, "Several direct children match target #{target} from #{current}" if matching.length > 1
      break if matching.empty?
      current = resolve_declared(current, matching.first.fetch("path"))
    end
    route
  end

  def resolve_active_scope(start_path, entry_scope = nil, explicit_local = nil)
    entry_map = entry_scope ? scope_map_path(entry_scope) : nearest_scope_map(start_path)
    route = composed_route(entry_map, start_path)
    active_map = route.last.fetch("resolved_path")
    local_candidates = route.each_with_object([]) do |record, candidates|
      local_path = File.join(File.dirname(record["resolved_path"]), ".agents", "local")
      next unless File.directory?(local_path) && File.readable?(local_path)
      candidates << {
        "scope" => record["resolved_path"],
        "scope_name" => record["name"],
        "path" => local_path,
        "plans_path" => File.join(local_path, "plans")
      }
    end

    selected = nil
    selection_reason = nil
    if explicit_local
      requested = absolute(explicit_local)
      selected = local_candidates.find { |candidate| candidate["path"] == requested }
      raise ToolError, "Explicit local directory is not owned by the composed route: #{requested}" unless selected
      selection_reason = "explicit"
    else
      active_local = local_candidates.find { |candidate| candidate["scope"] == active_map }
      if active_local
        selected = active_local
        selection_reason = "active_scope"
      end
    end
    warnings = []
    warnings << "The active scope owns no .agents/local directory; pass --local explicitly to select another scope on the composed route" if selected.nil?
    {
      "entry_scope" => route.first,
      "active_scope" => scope_record(active_map),
      "route" => route,
      "local_candidates" => local_candidates,
      "selected_local" => selected,
      "selection_reason" => selection_reason,
      "ambiguous" => false,
      "boundaries" => [],
      "warnings" => warnings
    }
  end

  def render_frontmatter(data, body)
    yaml = YAML.dump(data).sub(/\A---\s*\n/, "")
    "---\n#{yaml}---\n#{body || ""}"
  end

  def atomic_write(path, content)
    directory = File.dirname(path)
    FileUtils.mkdir_p(directory)
    mode = File.exist?(path) ? File.stat(path).mode : 0o644
    temporary = Tempfile.new([".scope-tool-", ".tmp"], directory)
    temporary.binmode
    temporary.write(content)
    temporary.flush
    temporary.fsync
    temporary.chmod(mode)
    temporary.close
    File.rename(temporary.path, path)
  ensure
    temporary&.close!
  end

  def apply_transaction(changes)
    originals = changes.to_h { |path, _content| [path, File.exist?(path) ? File.binread(path) : nil] }
    applied = []
    changes.each do |path, content|
      atomic_write(path, content)
      applied << path
    end
  rescue StandardError => e
    applied.reverse_each do |path|
      original = originals[path]
      original.nil? ? FileUtils.rm_f(path) : atomic_write(path, original)
    end
    raise ToolError, "Scope update rolled back after write failure: #{e.message}"
  end

  def titleize(name)
    name.split("-").map(&:capitalize).join(" ")
  end

  def template_path(name)
    File.expand_path(File.join("..", "templates", name), __dir__)
  end

  def new_scope_body(name)
    File.read(template_path("AGENTS.md.template"))
      .gsub("{{SCOPE_NAME}}", name)
      .gsub("{{SCOPE_TITLE}}", titleize(name))
  end

  def setup_scope(options)
    scope_dir = absolute(options.fetch(:scope_dir))
    map_path = File.join(scope_dir, "AGENTS.md")

    if File.file?(map_path)
      data, body = read_frontmatter(map_path, include_body: true)
      validate_scope_header!(data, map_path)
    else
      %i[name description].each do |key|
        raise ToolError, "--#{key} is required for a new scope" if options[key].to_s.strip.empty?
      end
      data = {
        "name" => options[:name],
        "description" => options[:description]
      }
      data["type"] = options[:type] if options[:type]
      body = new_scope_body(options[:name])
    end

    data["name"] = options[:name] if options[:name]
    data["description"] = options[:description] if options[:description]
    data["type"] = options[:type] if options[:type]
    data["confidential"] = true if options[:confidential]

    { context: "context", skills: "skill" }.each do |option_key, kind|
      options.fetch(option_key, []).each do |resource_path|
        resolved = absolute(resource_path, scope_dir)
        resource_data, = read_frontmatter(resolved)
        validate_resource_header!(resource_data, resolved)
        declared = relative_path(resolved, scope_dir)
        list_key = kind == "skill" ? "skills" : "context"
        data["resources"] ||= {}
        data["resources"][list_key] ||= []
        data["resources"][list_key] << declared unless data["resources"][list_key].include?(declared)
      end
    end

    validate_scope_header!(data, map_path)
    changes = [[map_path, render_frontmatter(data, body)]]
    changes.concat(local_changes(scope_dir, data["name"])) if options[:with_local]
    result = {
      "operation" => options[:dry_run] ? "dry_run" : "setup",
      "scope" => map_path,
      "changes" => changes.map(&:first),
      "boundaries" => [],
      "boundary" => nil
    }
    return result if options[:dry_run]

    apply_transaction(changes)
    result
  end

  def register_child(options)
    parent_map = scope_map_path(options.fetch(:scope))
    child_map = scope_map_path(options.fetch(:child), File.dirname(parent_map))
    raise ToolError, "--child must resolve to AGENTS.md: #{child_map}" unless File.basename(child_map) == "AGENTS.md"
    hint = options.fetch(:when).to_s.strip
    raise ToolError, "--when must be a concise non-empty routing hint" if hint.empty?

    parent_data, parent_body = read_frontmatter(parent_map, include_body: true)
    validate_scope_header!(parent_data, parent_map)
    child_data, = read_frontmatter(child_map)
    validate_scope_header!(child_data, child_map)

    declared = relative_path(child_map, File.dirname(parent_map))
    parent_data["children"] ||= []
    existing = parent_data["children"].find { |entry| entry["path"] == declared }
    if existing
      existing["when"] = hint
    else
      parent_data["children"] << { "path" => declared, "when" => hint }
    end
    validate_scope_header!(parent_data, parent_map)
    changes = [[parent_map, render_frontmatter(parent_data, parent_body)]]
    result = {
      "operation" => options[:dry_run] ? "dry_run_register_child" : "register_child",
      "scope" => parent_map,
      "child" => child_map,
      "routing_hint" => hint,
      "changes" => changes.map(&:first)
    }
    return result if options[:dry_run]

    apply_transaction(changes)
    result
  end

  def local_changes(scope_dir, scope_name)
    local_dir = File.join(scope_dir, ".agents", "local")
    readme = File.read(template_path("local-README.md.template")).gsub("{{SCOPE_NAME}}", scope_name)
    files = {
      File.join(local_dir, "README.md") => readme,
      File.join(local_dir, ".gitignore") => File.read(template_path("local.gitignore.template")),
      File.join(local_dir, "context", ".gitkeep") => "",
      File.join(local_dir, "skills", ".gitkeep") => "",
      File.join(local_dir, "plans", ".gitkeep") => ""
    }
    files.reject { |path, _content| File.exist?(path) }.to_a
  end

  def repository_root(start_directory)
    current = absolute(start_directory)
    loop do
      return current if File.exist?(File.join(current, ".git"))
      parent = File.dirname(current)
      return absolute(start_directory) if parent == current
      current = parent
    end
  end

  def managed_adapter?(path)
    File.file?(path) && File.binread(path).include?("Generated by setup-agentic-scope")
  end

  def adapter_file(path, content)
    { "kind" => "file", "path" => path, "content" => content }
  end

  def adapter_symlink(path, target)
    { "kind" => "symlink", "path" => path, "target" => target }
  end

  def platform_adapter_operations(map_path, platforms)
    scope_dir = File.dirname(map_path)
    repo_root = repository_root(scope_dir)
    relative_scope = relative_path(scope_dir, repo_root)
    operations = []
    warnings = []
    native = []

    if platforms.include?("codex")
      native << { "platform" => "codex", "strategy" => "native-agents-and-skills" }
    end

    if platforms.include?("claude")
      claude_path = File.join(scope_dir, "CLAUDE.md")
      claude_content = File.read(template_path("CLAUDE.md.template"))
      if File.exist?(claude_path) && !managed_adapter?(claude_path) && File.binread(claude_path) != "@AGENTS.md\n"
        raise ToolError, "Refusing to overwrite unmanaged Claude adapter: #{claude_path}"
      end
      operations << adapter_file(claude_path, claude_content)

      canonical_skills = File.join(scope_dir, ".agents", "skills")
      claude_skills = File.join(scope_dir, ".claude", "skills")
      if File.directory?(canonical_skills)
        if File.exist?(claude_skills) && !File.symlink?(claude_skills)
          raise ToolError, "Refusing to replace non-symlink Claude skills path: #{claude_skills}"
        end
        operations << adapter_symlink(claude_skills, "../.agents/skills")
      else
        warnings << "Claude skills adapter omitted because canonical directory is absent: #{canonical_skills}"
      end
    end

    if platforms.include?("cursor")
      cursor_path = File.join(scope_dir, ".cursor", "rules", "agentic-scope.mdc")
      cursor_content = File.read(template_path("cursor-agentic-scope.mdc.template"))
      if File.exist?(cursor_path) && !managed_adapter?(cursor_path)
        raise ToolError, "Refusing to overwrite unmanaged Cursor adapter: #{cursor_path}"
      end
      operations << adapter_file(cursor_path, cursor_content)
    end

    if platforms.include?("copilot")
      if scope_dir == repo_root
        copilot_path = File.join(repo_root, ".github", "copilot-instructions.md")
        copilot_content = File.read(template_path("copilot-repository.md.template"))
      else
        adapter_name = relative_scope.split(File::SEPARATOR).join("--")
        copilot_path = File.join(repo_root, ".github", "instructions", "#{adapter_name}.instructions.md")
        copilot_content = File.read(template_path("copilot-scope.instructions.md.template"))
          .gsub("{{SCOPE_PATH}}", relative_scope)
      end
      if File.exist?(copilot_path) && !managed_adapter?(copilot_path)
        raise ToolError, "Refusing to overwrite unmanaged Copilot adapter: #{copilot_path}"
      end
      operations << adapter_file(copilot_path, copilot_content)
    end

    [operations, warnings, native]
  end

  def adapter_operation_current?(operation)
    path = operation["path"]
    if operation["kind"] == "file"
      File.file?(path) && File.binread(path) == operation["content"]
    else
      File.symlink?(path) && File.readlink(path) == operation["target"] && File.exist?(path)
    end
  end

  def apply_adapter_operations(operations)
    originals = operations.to_h do |operation|
      path = operation["path"]
      state = if File.symlink?(path)
                { "kind" => "symlink", "target" => File.readlink(path) }
              elsif File.file?(path)
                { "kind" => "file", "content" => File.binread(path) }
              else
                nil
              end
      [path, state]
    end
    applied = []
    operations.each do |operation|
      next if adapter_operation_current?(operation)
      path = operation["path"]
      FileUtils.mkdir_p(File.dirname(path))
      FileUtils.rm_f(path) if File.symlink?(path)
      if operation["kind"] == "file"
        atomic_write(path, operation["content"])
      else
        File.symlink(operation["target"], path)
      end
      applied << path
    end
  rescue StandardError => e
    applied.reverse_each do |path|
      FileUtils.rm_f(path)
      original = originals[path]
      next unless original
      if original["kind"] == "file"
        atomic_write(path, original["content"])
      else
        File.symlink(original["target"], path)
      end
    end
    raise ToolError, "Adapter update rolled back after write failure: #{e.message}"
  end

  def adapters(scope_path, platforms, dry_run:, check:)
    map_path = scope_map_path(scope_path)
    data, = read_frontmatter(map_path)
    validate_scope_header!(data, map_path)
    operations, warnings, native = platform_adapter_operations(map_path, platforms)
    pending = operations.reject { |operation| adapter_operation_current?(operation) }
    errors = check ? pending.map { |operation| "Adapter missing or stale: #{operation['path']}" } : []

    apply_adapter_operations(operations) unless dry_run || check
    {
      "operation" => check ? "check_adapters" : (dry_run ? "dry_run_adapters" : "adapters"),
      "scope" => map_path,
      "platforms" => platforms,
      "native" => native,
      "changes" => pending.map { |operation| operation["path"] },
      "valid" => errors.empty?,
      "errors" => errors,
      "warnings" => warnings
    }
  end

  def candidates(scope_path, under_paths)
    map_path = scope_map_path(scope_path)
    data, = read_frontmatter(map_path)
    validate_scope_header!(data, map_path)
    registered = child_entries(data).to_h do |entry|
      [resolve_declared(map_path, entry.fetch("path")), entry.fetch("when")]
    end
    output = []

    under_paths.each do |under|
      container = absolute(under, File.dirname(map_path))
      raise ToolError, "Candidate container is not a readable directory: #{container}" unless File.directory?(container) && File.readable?(container)
      Dir.children(container).sort.each do |entry|
        child_map = File.join(container, entry, "AGENTS.md")
        next unless File.file?(child_map) && File.readable?(child_map)
        child_data, = read_frontmatter(child_map)
        validate_scope_header!(child_data, child_map)
        output << {
          "name" => child_data["name"],
          "description" => child_data["description"],
          "resolved_path" => child_map,
          "registered" => registered.key?(child_map),
          "routing_hint" => registered[child_map]
        }
      end
    end
    { "scope" => map_path, "candidates" => output.uniq { |item| item["resolved_path"] } }
  end

  def validate_scope(scope_path)
    map_path = scope_map_path(scope_path)
    errors = []
    warnings = []

    begin
      data, = read_frontmatter(map_path)
      validate_scope_header!(data, map_path)
      local_names = { "context" => {}, "skill" => {} }
      { "context" => resource_paths(data, "context"), "skill" => resource_paths(data, "skills") }.each do |kind, paths|
        paths.each do |declared|
          resolved = resolve_declared(map_path, declared)
          resource_data, = read_frontmatter(resolved)
          validate_resource_header!(resource_data, resolved)
          name = resource_data["name"]
          errors << "Duplicate #{kind} name '#{name}' in #{map_path}" if local_names[kind][name]
          local_names[kind][name] = resolved
        rescue ToolError => e
          errors << e.message
        end
      end

      child_names = {}
      child_hints = {}
      child_entries(data).each do |entry|
        declared = entry.fetch("path")
        normalized_hint = entry.fetch("when").downcase.gsub(/\s+/, " ").strip
        if child_hints[normalized_hint]
          warnings << "Direct children share the same routing hint '#{entry.fetch('when')}': #{child_hints[normalized_hint]} and #{declared}; ambiguous requests require clarification"
        else
          child_hints[normalized_hint] = declared
        end
        child_map = resolve_declared(map_path, declared)
        begin
          errors << "Child path must point to AGENTS.md: #{declared}" unless File.basename(child_map) == "AGENTS.md"
          child_data, = read_frontmatter(child_map)
          validate_scope_header!(child_data, child_map)
          child_name = child_data["name"]
          if child_names[child_name]
            errors << "Duplicate direct-child name '#{child_name}': #{child_names[child_name]} and #{child_map}"
          else
            child_names[child_name] = child_map
          end
        rescue ToolError => e
          errors << e.message
        end
      end
    rescue ToolError => e
      errors << e.message
    end
    { "scope" => map_path, "valid" => errors.empty?, "errors" => errors.uniq, "warnings" => warnings.uniq }
  end

  def path_within?(path, directory)
    expanded_path = absolute(path)
    expanded_directory = absolute(directory)
    expanded_path == expanded_directory || expanded_path.start_with?(expanded_directory + File::SEPARATOR)
  end

  def validate_scope_tree(scope_path)
    root_map = scope_map_path(scope_path)
    scope_results = []
    recorded_results = {}
    errors = []
    warnings = []

    walk = lambda do |map_path, route_stack, effective_skills|
      if route_stack.include?(map_path)
        errors << "Child-registration cycle detected: #{(route_stack + [map_path]).join(' -> ')}"
        next
      end

      result = validate_scope(map_path)
      unless recorded_results[map_path]
        scope_results << result
        recorded_results[map_path] = true
      end
      errors.concat(result["errors"].map { |message| "#{map_path}: #{message}" })
      warnings.concat(result["warnings"].map { |message| "#{map_path}: #{message}" })
      next unless File.file?(map_path) && File.readable?(map_path)

      begin
        data, = read_frontmatter(map_path)
        validate_scope_header!(data, map_path)
        route_skills = effective_skills.dup
        resource_paths(data, "skills").each do |declared|
          skill_path = resolve_declared(map_path, declared)
          skill_data, = read_frontmatter(skill_path)
          validate_resource_header!(skill_data, skill_path)
          name = skill_data["name"]
          if effective_skills[name]
            warnings << "#{map_path}: Skill '#{name}' shadows ancestor declaration #{effective_skills[name]} with #{skill_path}"
          end
          route_skills[name] = skill_path
        rescue ToolError => e
          errors << "#{map_path}: #{e.message}"
        end

        children = child_entries(data).map do |entry|
          child_map = resolve_declared(map_path, entry.fetch("path"))
          child_data, = read_frontmatter(child_map)
          validate_scope_header!(child_data, child_map)
          { "map" => child_map, "dir" => File.dirname(child_map), "data" => child_data, "when" => entry.fetch("when") }
        rescue ToolError => e
          errors << "#{map_path}: #{e.message}"
          nil
        end.compact

        children.each do |child|
          %w[context skills].each do |kind|
            resource_paths(child["data"], kind).each do |declared|
              resolved = resolve_declared(child["map"], declared)
              sibling = children.find { |candidate| candidate != child && path_within?(resolved, candidate["dir"]) }
              next unless sibling
              errors << "#{child['map']}: Cross-sibling #{kind} reference '#{declared}' resolves inside #{sibling['map']}"
            end
          end
        end

        confidential = children.select { |child| child.dig("data", "confidential") == true }
        confidential.group_by { |child| repository_root(child["dir"]) }.each do |repo, group|
          next unless group.length > 1
          warnings << "#{map_path}: Confidential sibling scopes share readable repository #{repo}: #{group.map { |child| child.dig('data', 'name') }.join(', ')}"
        end

        children.each { |child| walk.call(child["map"], route_stack + [map_path], route_skills) }
      rescue ToolError => e
        errors << "#{map_path}: #{e.message}"
      end
    end

    walk.call(root_map, [], {})

    {
      "scope" => root_map,
      "descendants" => true,
      "scopes" => scope_results,
      "valid" => errors.empty?,
      "errors" => errors.uniq,
      "warnings" => warnings.uniq
    }
  end

  def emit(result, format)
    if format == "json"
      puts JSON.pretty_generate(result)
    elsif result.key?("records")
      result["records"].each do |record|
        puts "#{record['kind']}: #{record['name']} — #{record['description']}"
        puts "  path: #{record['resolved_path']}"
        puts "  declared by: #{record['declared_by']}"
        puts "  when: #{record['routing_hint']}" if record["routing_hint"]
      end
      result["boundaries"].each { |item| puts "boundary: #{item['resolved_path']}" }
    elsif result.key?("candidates")
      result["candidates"].each do |item|
        puts "#{item['registered'] ? 'registered' : 'unregistered'}: #{item['name']} — #{item['resolved_path']}"
      end
    elsif result.key?("active_scope")
      puts "active scope: #{result.dig('active_scope', 'resolved_path')}"
      if result["selected_local"]
        puts "local: #{result.dig('selected_local', 'path')} (#{result['selection_reason']})"
      else
        puts "local: unresolved"
      end
      result["warnings"].each { |message| puts "warning: #{message}" }
    elsif result["operation"]&.include?("adapter")
      puts "#{result['operation']}: #{result['scope']}"
      result["native"].each { |item| puts "native: #{item['platform']} (#{item['strategy']})" }
      result["changes"].each { |path| puts "change: #{path}" }
      result["errors"].each { |message| puts "error: #{message}" }
      result["warnings"].each { |message| puts "warning: #{message}" }
    elsif result.key?("valid")
      puts(result["valid"] ? "valid: #{result['scope']}" : "invalid: #{result['scope']}")
      result["errors"].each { |message| puts "error: #{message}" }
      result["warnings"].each { |message| puts "warning: #{message}" }
    else
      puts "#{result['operation']}: #{result['scope']}"
      result["changes"].each { |path| puts "change: #{path}" }
      puts "boundary: #{result['boundary']['resolved_path']}" if result["boundary"]
    end
  end

  def format_option(parser, options)
    parser.on("--format FORMAT", %w[text json]) { |value| options[:format] = value }
  end

  def run(argv)
    if argv.empty? || %w[-h --help].include?(argv.first)
      puts HELP
      return
    end

    command = argv.shift

    case command
    when "resolve"
      options = { start: Dir.pwd, format: "json" }
      parser = OptionParser.new do |opts|
        opts.on("--start PATH") { |value| options[:start] = value }
        opts.on("--entry PATH") { |value| options[:entry] = value }
        opts.on("--local PATH") { |value| options[:local] = value }
        format_option(opts, options)
      end
      parser.parse!(argv)
      result = resolve_active_scope(options[:start], options[:entry], options[:local])
      emit(result, options[:format])
    when "inspect"
      options = { includes: ["map"], format: "json" }
      parser = OptionParser.new do |opts|
        opts.on("--scope PATH") { |value| options[:scope] = value }
        opts.on("--include LIST") { |value| options[:includes] = value.split(",").map(&:strip) }
        format_option(opts, options)
      end
      parser.parse!(argv)
      raise ToolError, "--scope is required" unless options[:scope]
      unknown = options[:includes] - %w[map resources children]
      raise ToolError, "Unknown --include value: #{unknown.join(', ')}" unless unknown.empty?
      emit(inspect_scope(options[:scope], options[:includes]), options[:format])
    when "setup"
      options = { with_local: false, dry_run: false, format: "json", context: [], skills: [] }
      parser = OptionParser.new do |opts|
        opts.on("--scope-dir PATH") { |value| options[:scope_dir] = value }
        opts.on("--name NAME") { |value| options[:name] = value }
        opts.on("--description TEXT") { |value| options[:description] = value }
        opts.on("--type TYPE") { |value| options[:type] = value }
        opts.on("--confidential") { options[:confidential] = true }
        opts.on("--context PATH") { |value| options[:context] << value }
        opts.on("--skill PATH") { |value| options[:skills] << value }
        opts.on("--with-local") { options[:with_local] = true }
        opts.on("--dry-run") { options[:dry_run] = true }
        format_option(opts, options)
      end
      parser.parse!(argv)
      raise ToolError, "--scope-dir is required" unless options[:scope_dir]
      emit(setup_scope(options), options[:format])
    when "register-child"
      options = { dry_run: false, format: "json" }
      parser = OptionParser.new do |opts|
        opts.on("--scope PATH") { |value| options[:scope] = value }
        opts.on("--child PATH") { |value| options[:child] = value }
        opts.on("--when TEXT") { |value| options[:when] = value }
        opts.on("--dry-run") { options[:dry_run] = true }
        format_option(opts, options)
      end
      parser.parse!(argv)
      %i[scope child when].each do |key|
        raise ToolError, "--#{key} is required" if options[key].to_s.strip.empty?
      end
      emit(register_child(options), options[:format])
    when "candidates"
      options = { under: [], format: "json" }
      parser = OptionParser.new do |opts|
        opts.on("--scope PATH") { |value| options[:scope] = value }
        opts.on("--under PATH") { |value| options[:under] << value }
        format_option(opts, options)
      end
      parser.parse!(argv)
      raise ToolError, "--scope is required" unless options[:scope]
      raise ToolError, "At least one --under path is required" if options[:under].empty?
      emit(candidates(options[:scope], options[:under]), options[:format])
    when "adapters"
      options = { platforms: %w[codex claude cursor copilot], dry_run: false, check: false, format: "json" }
      parser = OptionParser.new do |opts|
        opts.on("--scope PATH") { |value| options[:scope] = value }
        opts.on("--platforms LIST") { |value| options[:platforms] = value.split(",").map(&:strip) }
        opts.on("--dry-run") { options[:dry_run] = true }
        opts.on("--check") { options[:check] = true }
        format_option(opts, options)
      end
      parser.parse!(argv)
      raise ToolError, "--scope is required" unless options[:scope]
      unknown = options[:platforms] - %w[codex claude cursor copilot]
      raise ToolError, "Unknown platform: #{unknown.join(', ')}" unless unknown.empty?
      raise ToolError, "--dry-run and --check cannot be combined" if options[:dry_run] && options[:check]
      result = adapters(options[:scope], options[:platforms], dry_run: options[:dry_run], check: options[:check])
      emit(result, options[:format])
      exit 1 unless result["valid"]
    when "validate"
      options = { format: "json", descendants: false }
      parser = OptionParser.new do |opts|
        opts.on("--scope PATH") { |value| options[:scope] = value }
        opts.on("--descendants") { options[:descendants] = true }
        format_option(opts, options)
      end
      parser.parse!(argv)
      raise ToolError, "--scope is required" unless options[:scope]
      result = options[:descendants] ? validate_scope_tree(options[:scope]) : validate_scope(options[:scope])
      emit(result, options[:format])
      exit 1 unless result["valid"]
    else
      raise ToolError, "Unknown command '#{command}'"
    end
  rescue OptionParser::ParseError => e
    raise ToolError, e.message
  end
end

begin
  AgenticScope.run(ARGV)
rescue AgenticScope::ToolError => e
  warn "scope-tool: #{e.message}"
  exit 1
end
