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
#       - concatenate: "\n\n---\n\n"
#       - msword_hrs
#
# A vault may define extra steps in <vault>/bin/compile_steps.rb; they're
# loaded automatically and can be referenced by name in the steps list.

require 'yaml'
require 'date'
require 'json'
require 'fileutils'
require 'optparse'

module Compile
  class Error < StandardError; end

  # ---------------------------------------------------------------- Steps --

  # Each step takes (text, scene, options) and returns text. `scene` is nil for
  # steps that run once over the joined manuscript.
  module Steps
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
      separator = opts.is_a?(String) ? opts : "\n\n---\n\n"
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
      { 'concatenate' => "\n\n---\n\n" },
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

    def run
      missing = @draft.missing
      raise Error, "missing scene files:\n  #{missing.join("\n  ")}" unless missing.empty?

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

    private

    def parse_step(step)
      return [step, nil] if step.is_a?(String)
      return step.first if step.is_a?(Hash) && step.size == 1

      raise Error, "malformed step: #{step.inspect}"
    end

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

    # 3. Longform's selection
    longform_selection(vault) || drafts(vault).first
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
      puts format('%s %-46s %3d scenes', marker, d.title[0, 46], d.scenes.length)
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
  text = Compile::Runner.new(draft, vault: vault).run
  target = draft.output

  words = text.split(/\s+/).length

  if options[:write]
    File.write(target, text)
    puts format('%s -> %s', draft.title, File.basename(target))
    puts format('  %d scenes, %d words', draft.scenes.length, words)

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
          puts "IDENTICAL to #{File.basename(target)} (#{words} words)"
        else
          puts "DIFFERS from #{File.basename(target)}"
          system('diff', target, f.path)
        end
      end
    else
      puts "would write #{File.basename(target)} (#{words} words)"
    end
  end
rescue Compile::Error => e
  warn "compile.rb: #{e.message}"
  exit 1
end
end
