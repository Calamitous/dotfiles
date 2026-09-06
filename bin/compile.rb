#!/usr/bin/env ruby
# frozen_string_literal: true

# compile.rb -- build a manuscript from a Longform draft.
#
# Replaces the Longform compile chain with one script. The draft (scene list
# and order) is still read from the same Index.md that Obsidian uses, so both
# tools stay usable on the same vault.
#
#   compile.rb                     compile the draft for the current directory
#   compile.rb path/to/Index.md    compile a specific draft
#   compile.rb --list              list drafts in this vault
#   compile.rb --check             compile but don't write; diff against target
#   compile.rb --docx              also render a .docx via pandoc
#
# WHICH DRAFT gets compiled, first match wins:
#
#   1. the nearest Index.md at or above the working directory -- so standing in
#      a book's folder compiles that book, and nvim (which runs this from the
#      buffer's directory) compiles whatever you're editing
#   2. <vault>/.compile-draft, set by --select
#   3. Longform's own selectedDraftVaultPath, read from its data.json
#   4. the only draft, if the vault has exactly one
#
# Otherwise it lists the drafts and stops. It never guesses between them.
#
# READ-ONLY toward Obsidian. It never writes Index.md or anything under
# .obsidian/ -- Obsidian caches those in memory and flushes on change, so an
# outside write can be silently clobbered.
#
# Configuration lives in Index.md as a `compile:` key SIBLING to `longform:`
# (never nested inside it -- Longform rebuilds that key wholesale on every
# write and would destroy anything under it):
#
#   compile:
#     output: Brass, Bone, & Steel Volume 1.md
#     steps:
#       - strip_frontmatter
#       - remove_links
#       - crunch_comments
#       - prepend_title: "# Chapter $title"
#       - concatenate: "\n\n"
#       - msword_hrs
#
# A vault may define extra steps in <vault>/bin/compile_steps.rb; they're
# loaded automatically and can be referenced by name in the steps list.

require 'set'
require 'yaml'
require 'date'
require 'json'
require 'fileutils'
require 'optparse'

module Compile
  class Error < StandardError; end

  # 136525 -> "136,525"
  def self.commas(number)
    number.to_s.gsub(/(\d)(?=(\d{3})+\z)/, '\\1,')
  end


  # Each step takes (text, scene, options) and returns text. `scene` is nil for
  # steps that run once over the joined manuscript.
  module Steps

    # ---------------------------------------------------------------- Steps --

    # Which position each step may occupy, mirroring Longform's availableKinds:
    #
    #   :scene     runs once per chapter, BEFORE the join
    #   :join      combines the chapters into one document (exactly one of these)
    #   :document  runs once over the whole manuscript, AFTER the join
    #
    # Position in the `steps:` list decides which a step is -- anything before
    # `concatenate` is a scene step, anything after is a document step -- so this
    # table is what catches an order that can't work.
    STEP_KINDS = {
      'strip_frontmatter' => %i[scene document],
      'remove_links' => %i[scene document],
      'remove_wikilinks' => %i[scene document],
      'remove_external_links' => %i[scene document],
      'crunch_comments' => %i[scene document],
      'prepend_title' => %i[scene],
      'concatenate' => %i[join],
      'msword_hrs' => %i[scene document],
      'markdown_hrs' => %i[scene document]
    }.freeze

    # One line each, for `--steps`.
    STEP_DESCRIPTIONS = {
      'strip_frontmatter' => 'remove the YAML frontmatter block',
      'remove_links' => 'wikilinks and [text](url) reduced to their text',
      'remove_wikilinks' => '[[Note|shown]] -> shown',
      'remove_external_links' => '[shown](url) -> shown',
      'crunch_comments' => 'drop %%obsidian%% and <!-- html --> comments',
      'prepend_title' => 'add a heading; $title and $n are substituted',
      'concatenate' => 'join the chapters with a separator',
      'msword_hrs' => '--- becomes +++ so pandoc makes correct Word docs',
      'markdown_hrs' => 'the inverse: +++ back to ---'
    }.freeze

    module_function

    # NOTE: the trailing newline after the closing `---` is deliberately NOT
    # consumed. Longform leaves it, and it becomes the blank line between a
    # chapter heading and the text. Removing it shifts every chapter by a line.
    FRONTMATTER = /\A---\r?\n.*?\r?\n---[ \t]*/m

    def strip_frontmatter(text, *)
      text.sub(FRONTMATTER, '')
    end

    # `[[Note|shown]]` -> `shown`, `[[Note]]` -> `Note`, `![[Note]]` -> `Note`.
    def remove_wikilinks(text, *)
      text.gsub(/!?\[\[([^\]|]*)\|([^\]]*)\]\]/, '\2')
          .gsub(/!?\[\[([^\]]*)\]\]/, '\1')
    end

    # `[shown](url)` -> `shown`
    def remove_external_links(text, *)
      text.gsub(/\[([^\]]*)\]\([^)]*\)/, '\1')
    end

    def remove_links(text, *)
      remove_external_links(remove_wikilinks(text))
    end

    # Obsidian %%..%% and HTML comments. Whole-line comments take the line with
    # them; inline ones are cut in place. Ported from CrunchComments.js.
    def crunch_comments(text, *)
      # \s (not [ \t]) on both sides, matching CrunchComments.js: it also
      # swallows blank lines left behind where a run of comments was removed.
      text = text.gsub(/^\s*%%(.*?)%%\s*/m, '')
      text = text.gsub(/^\s*<!--(.*?)-->\s*\r?\n/m, '')
      text = text.gsub(/%%(.*?)%%/m, '')
      text.gsub(/<!--(.*?)-->/m, '')
    end

    # `$title` is the scene name; `$n` its 1-based position.
    def prepend_title(text, scene, opts)
      format = opts.is_a?(String) ? opts : '# $title'
      heading = format.gsub('$title', scene[:title].to_s).gsub('$n', scene[:index].to_s)
      "#{heading}\n\n#{text}"
    end

    def concatenate(parts, _scene, opts)
      separator = opts.is_a?(String) ? opts : "\n\n"
      parts.join(separator)
    end

    # Pandoc renders `---` as a horizontal rule that Word mishandles; `+++`
    # survives the trip. Ported from "MSWord-ify HRs.js".
    def msword_hrs(text, *)
      text.gsub(/\n---\n/, "\n+++\n")
    end

    # The inverse, for a manuscript meant to be read as markdown.
    def markdown_hrs(text, *)
      text.gsub(/\n\+\+\+\n/, "\n---\n")
    end
  end

  # --------------------------------------------------------------- Draft ---

  class Draft
    attr_reader :path, :dir, :title, :scenes, :config

    DEFAULT_STEPS = [
      'strip_frontmatter',
      'remove_links',
      'crunch_comments',
      { 'prepend_title' => '# Chapter $title' },
      { 'concatenate' => "\n\n" },
      'msword_hrs'
    ].freeze

    def initialize(path)
      @path = File.expand_path(path)
      @dir = File.dirname(@path)
      raise Error, "no such draft: #{@path}" unless File.file?(@path)

      front = Draft.frontmatter(@path)
      longform = front['longform'] or raise Error, "#{@path} has no `longform:` block"

      @title = longform['title'] || File.basename(@dir)
      @scenes = Array(longform['scenes']).flatten.compact
      @scene_folder = longform['sceneFolder']
      @config = front['compile'] || {}
    end

    def self.frontmatter(path)
      text = File.read(path)
      m = text.match(/\A---\r?\n(.*?)\r?\n---[ \t]*\r?\n/m)
      return {} unless m

      YAML.safe_load(m[1], permitted_classes: [Date], aliases: true) || {}
    rescue Psych::SyntaxError => e
      raise Error, "#{path}: invalid YAML frontmatter -- #{e.message}"
    end

    def scene_dir
      return @dir if @scene_folder.nil? || @scene_folder.empty? || @scene_folder == '/'

      File.join(@dir, @scene_folder.sub(%r{\A/}, '').sub(%r{/\z}, ''))
    end

    def scene_path(scene)
      File.join(scene_dir, "#{scene}.md")
    end

    def steps
      @config['steps'] || DEFAULT_STEPS
    end

    def output
      File.join(@dir, @config['output'] || "#{@title}.md")
    end

    def missing
      @scenes.reject { |s| File.file?(scene_path(s)) }
    end
  end

  # -------------------------------------------------------------- Runner ---

  class Runner
    def initialize(draft, vault: nil)
      @draft = draft
      @vault = vault
      load_custom_steps
    end

    # Check the pipeline before doing any work, so a bad order is a clear
    # message rather than a nil-error backtrace half way through.
    def validate!
      parsed = @draft.steps.map { |step| parse_step(step).first }

      joins = parsed.each_index.select { |i| Steps::STEP_KINDS[parsed[i]] == [:join] }

      if joins.empty?
        raise Error, "no join step: add `- concatenate: \"\\n\\n\"` " \
                     'to combine the chapters (without it they are joined with a blank line)'
      end
      if joins.length > 1
        raise Error, "#{joins.length} join steps; there must be exactly one"
      end

      join_at = joins.first

      parsed.each_with_index do |name, i|
        next if i == join_at

        allowed = Steps::STEP_KINDS[name]
        next if allowed.nil? # custom step from the vault: assume it knows

        position = i < join_at ? :scene : :document
        next if allowed.include?(position)

        where = position == :scene ? 'before' : 'after'
        want = allowed.include?(:scene) ? 'before' : 'after'
        raise Error, "`#{name}` cannot run #{where} the join -- it is a " \
                     "#{allowed.join('/')} step. Move it #{want} `concatenate`."
      end
    end

    def run
      missing = @draft.missing
      raise Error, "missing scene files:\n  #{missing.join("\n  ")}" unless missing.empty?

      validate!

      texts = @draft.scenes.each_with_index.map do |scene, i|
        { title: scene, index: i + 1, text: File.read(@draft.scene_path(scene)) }
      end

      joined = nil

      @draft.steps.each do |step|
        name, opts = parse_step(step)

        if name == 'concatenate'
          raise Error, 'concatenate ran twice' if joined

          joined = apply('concatenate', texts.map { |t| t[:text] }, nil, opts)
        elsif joined
          joined = apply(name, joined, nil, opts)
        else
          texts.each do |t|
            t[:text] = apply(name, t[:text], { title: t[:title], index: t[:index] }, opts)
          end
        end
      end

      joined || texts.map { |t| t[:text] }.join("\n\n")
    end

    # Extra steps a vault defines in bin/compile_steps.rb. They must be module
    # functions (`def self.name` or `module_function`) to be callable here.
    def custom_steps
      @custom.singleton_methods.map(&:to_s).sort
    end

    def parse_step(step)
      return [step, nil] if step.is_a?(String)
      return step.first if step.is_a?(Hash) && step.size == 1

      raise Error, "malformed step: #{step.inspect}"
    end

    private

    def apply(name, text, scene, opts)
      if @custom.respond_to?(name)
        @custom.public_send(name, text, scene, opts)
      elsif Steps.respond_to?(name)
        Steps.public_send(name, text, scene, opts)
      else
        raise Error, "unknown compile step: #{name}"
      end
    end

    # A vault can define extra steps in <vault>/bin/compile_steps.rb, so custom
    # behaviour is versioned with the book rather than duplicated in this file.
    def load_custom_steps
      @custom = Module.new
      return unless @vault

      file = File.join(@vault, 'bin', 'compile_steps.rb')
      return unless File.file?(file)

      @custom = Module.new
      @custom.module_eval(File.read(file), file)
    end
  end

  # -------------------------------------------------------------- Vaults ---

  module_function

  def vault_root(from = Dir.pwd)
    dir = File.expand_path(from)
    loop do
      return dir if Dir.exist?(File.join(dir, '.obsidian'))

      parent = File.dirname(dir)
      return nil if parent == dir

      dir = parent
    end
  end

  def drafts(vault)
    Dir.glob(File.join(vault, '**', 'Index.md'))
       .reject { |p| p.include?("#{File::SEPARATOR}.obsidian#{File::SEPARATOR}") }
       .select do |p|
         begin
           !Draft.frontmatter(p)['longform'].nil?
         rescue Error => e
           warn "compile.rb: skipping #{p} -- #{e.message}"
           false
         end
       end
       .sort
  end

  # Longform records the draft you picked in its own settings. Read it as a
  # default; never write it.
  def longform_selection(vault)
    data = File.join(vault, '.obsidian', 'plugins', 'longform', 'data.json')
    return nil unless File.file?(data)

    rel = JSON.parse(File.read(data))['selectedDraftVaultPath']
    return nil unless rel

    path = File.join(vault, rel)
    File.file?(path) ? path : nil
  rescue JSON::ParserError
    nil
  end

  # nvim's own selection wins when set; it's a file this tool owns.
  def selection_file(vault)
    File.join(vault, '.compile-draft')
  end

  def selected_draft(vault, from = Dir.pwd)
    # 1. an Index.md above the current directory
    dir = File.expand_path(from)
    while dir.start_with?(vault)
      candidate = File.join(dir, 'Index.md')
      return candidate if File.file?(candidate)

      parent = File.dirname(dir)
      break if parent == dir

      dir = parent
    end

    # 2. this tool's own selection
    file = selection_file(vault)
    if File.file?(file)
      path = File.join(vault, File.read(file).strip)
      return path if File.file?(path)
    end

    # 3. Longform's own selection
    chosen = longform_selection(vault)
    return chosen if chosen

    # 4. A vault with exactly one draft is unambiguous; more than one is not,
    #    and guessing is worse than saying so.
    available = drafts(vault)
    return available.first if available.length == 1

    if available.empty?
      raise Error, "no drafts in #{vault} (looked for an Index.md with a `longform:` block)"
    end

    lines = available.map do |path|
      rel = path.sub("#{vault}/", '')
      title = (Draft.new(path).title rescue rel)
      format('    %-52s %s', rel, title)
    end

    raise Error, <<~MSG.chomp
      #{available.length} drafts here and nothing to choose between them.

      Pick one by:
        cd-ing into the book's folder, or
        compile.rb <path to its Index.md>, or
        compile.rb --select <path to its Index.md>   (remembers it)

      Available:
      #{lines.join("\n")}
    MSG
  end
end

# ----------------------------------------------------------------- Main ----

# Guard so `load`/`require` of this file can't trigger a compile.
if __FILE__ == $PROGRAM_NAME

options = { write: true, docx: false }

parser = OptionParser.new do |o|
  o.banner = 'Usage: compile.rb [options] [Index.md]'
  o.on('--list', 'List drafts in this vault') { options[:list] = true }
  o.on('--check', "Compile but don't write; diff against the current output") { options[:write] = false }
  o.on('--docx', 'Also render a .docx via pandoc') { options[:docx] = true }
  o.on('--steps', 'Show the compile pipeline for this draft') { options[:steps] = true }
  o.on('--select PATH', 'Remember PATH as this vault\'s draft') { |p| options[:select] = p }
  o.on('-h', '--help') { puts o; exit }
end
parser.parse!

begin
  vault = Compile.vault_root
  raise Compile::Error, 'not inside an Obsidian vault' unless vault

  if options[:list]
    current = Compile.selected_draft(vault)
    Compile.drafts(vault).each do |p|
      d = Compile::Draft.new(p)
      marker = (p == current ? '*' : ' ')
      puts format('%s %-46s %5s scenes', marker, d.title[0, 46], Compile.commas(d.scenes.length))
    end
    exit
  end

  if options[:select]
    rel = File.expand_path(options[:select]).sub("#{vault}/", '')
    File.write(Compile.selection_file(vault), rel)
    puts "selected: #{rel}"
    exit
  end

  index = ARGV[0] || Compile.selected_draft(vault)
  raise Compile::Error, 'no draft found' unless index

  draft = Compile::Draft.new(index)
  runner = Compile::Runner.new(draft, vault: vault)

  if options[:steps]
    runner.validate!
    names = draft.steps.map { |st| runner.parse_step(st).first }
    join_at = names.index { |n| Compile::Steps::STEP_KINDS[n] == [:join] }
    puts "#{draft.title}  (#{Compile.commas(draft.scenes.length)} scenes)"
    puts "  source: #{File.basename(draft.path)}#{draft.config.empty? ? '  [built-in defaults]' : ''}"
    puts
    names.each_with_index do |name, i|
      kind = i == join_at ? 'join    ' : (i < join_at ? 'scene   ' : 'document')
      puts format('  %-8s %s', kind, name)
    end
    puts
    puts '  scene    = runs once per chapter'
    puts '  join     = combines them into one document'
    puts '  document = runs once over the whole manuscript'
    puts

    used = names.to_set rescue names
    mark = ->(n) { (used.include?(n) ? '*' : ' ') }

    groups = {
      'scene or document' => [],
      'scene only' => [],
      'join' => []
    }
    Compile::Steps::STEP_KINDS.each do |name, kinds|
      key = if kinds == [:join] then 'join'
            elsif kinds == [:scene] then 'scene only'
            else 'scene or document'
            end
      groups[key] << name
    end

    puts 'Available steps   (* = used above)'
    groups.each do |label, list|
      next if list.empty?

      puts "  #{label}:"
      list.sort.each do |name|
        puts format('    %s %-24s %s', mark.call(name), name,
                    Compile::Steps::STEP_DESCRIPTIONS[name] || '')
      end
    end

    custom = runner.custom_steps
    puts '  from this vault (bin/compile_steps.rb):'
    if custom.empty?
      puts '      (none)'
    else
      custom.each { |name| puts format('    %s %s', mark.call(name), name) }
    end
    exit
  end

  text = runner.run
  target = draft.output

  words = text.split(/\s+/).length

  if options[:write]
    File.write(target, text)
    puts format('%s -> %s', draft.title, File.basename(target))
    puts format('  %s scenes, %s words', Compile.commas(draft.scenes.length), Compile.commas(words))

    if options[:docx]
      docx = target.sub(/\.md\z/, '.docx')
      system('pandoc', '-f', 'markdown', '-o', docx, target) or raise Compile::Error, 'pandoc failed'
      puts "  #{File.basename(docx)}"
    end
  else
    if File.file?(target)
      require 'tempfile'
      Tempfile.create(['compiled', '.md']) do |f|
        f.write(text)
        f.flush
        if system('diff', '-q', target, f.path, out: File::NULL)
          puts "IDENTICAL to #{File.basename(target)} (#{Compile.commas(words)} words)"
        else
          puts "DIFFERS from #{File.basename(target)}"
          system('diff', target, f.path)
        end
      end
    else
      puts "would write #{File.basename(target)} (#{Compile.commas(words)} words)"
    end
  end
rescue Compile::Error => e
  warn "compile.rb: #{e.message}"
  exit 1
end
end
