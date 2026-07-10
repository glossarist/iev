#!/usr/bin/env ruby
# frozen_string_literal: true

# Reconcile the historical termbase (iev-data/termbase.yaml, ~2020 snapshot)
# with the live Electropedia HTML mirror (iev-data-latest/pages/) into a
# single Glossarist V3 dataset with full lifecycle history.
#
# Usage:
#   bundle exec ruby scripts/reconcile.rb [--output DIR] [--limit N]
#
# Output:
#   <output>/concepts/concept-<code>.yaml  — one V3 ManagedConcept per code
#   <output>/register.yaml                 — dataset register
#
# The output captures three populations:
#   1. In both sources  → live content + termbase dates/status
#   2. Termbase only     → retired, full historical content preserved
#   3. Live only         → new concept, accepted from publication date

SCRIPT_DIR = File.expand_path(__dir__)
REPO_ROOT = File.expand_path("..", SCRIPT_DIR)

require "bundler/setup"
require "iev"
require "nokogiri"
require "yaml"
require "fileutils"
require "optparse"
require "date"

module Iev
  module Reconciler
    MIRROR_DATE = Date.today.iso8601

    # ─── Status mapping ───

    STATUS_MAP = {
      "Standard" => "valid",
      "Published" => "valid",
      "Draft" => "draft",
      "Not Valid" => "notValid",
      "Superseded" => "superseded",
      "Retired" => "retired",
      "Effective" => "valid",
    }.freeze

    def self.map_status(entry_status)
      STATUS_MAP[entry_status] || "valid"
    end

    # ─── Date extraction ───

    def self.extract_dates(lang_data)
      dates = []
      if lang_data["date_accepted"]
        dates << { "type" => "accepted", "date" => normalize_date(lang_data["date_accepted"]) }
      end
      if lang_data["date_amended"] && lang_data["date_amended"] != lang_data["date_accepted"]
        dates << { "type" => "amended", "date" => normalize_date(lang_data["date_amended"]) }
      end
      dates
    end

    def self.normalize_date(iso8601_str)
      return nil unless iso8601_str
      Date.parse(iso8601_str.to_s).iso8601
    rescue Date::Error
      iso8601_str.to_s[0, 10]
    end

    # ─── Termbase concept → V3 hash ───

    def self.termbase_to_v3(code, tb_entry)
      eng = tb_entry["eng"] || tb_entry.values.find { |v| v.is_a?(Hash) && v["terms"] }
      return nil unless eng

      dates = extract_dates(eng).uniq { |d| d.values }
      status = map_status(eng["entry_status"])

      localized = {}
      tb_entry.each do |lang, data|
        next unless data.is_a?(Hash) && data["terms"]
        localized[lang] = build_v3_localized(code, lang, data)
      end

      {
        "schema_version" => "3",
        "identifier" => code,
        "status" => status,
        "dates" => dates,
        "localized_concepts" => localized.keys,
        "data" => {
          "identifier" => code,
          "localized_concepts" => localized,
        },
      }
    end

    def self.build_v3_localized(code, lang, data)
      terms = (data["terms"] || []).map do |t|
        term = { "type" => t["type"] || "expression" }
        term["designation"] = t["designation"]
        term["normative_status"] = t["normative_status"] || "preferred"
        term
      end

      result = {
        "id" => code,
        "language_code" => lang,
        "terms" => terms,
        "entry_status" => map_status(data["entry_status"]),
      }

      if data["definition"] && !data["definition"].empty?
        result["definition"] = [{ "content" => data["definition"] }]
      end
      result["notes"] = data["notes"].map { |n| { "content" => n } } if data["notes"]&.any?
      result["examples"] = data["examples"].map { |e| { "content" => e } } if data["examples"]&.any?

      dates = extract_dates(data)
      result["dates"] = dates if dates.any?

      result
    end

    # ─── Live HTML concept → V3 hash ───

    def self.live_to_v3(code, raw_parsed)
      data = raw_parsed && raw_parsed["data"]
      return nil unless data && data["localized_concepts"]&.any?

      localized = {}
      data["localized_concepts"].each do |lang, lc_data|
        localized[lang] = build_v3_localized_from_parsed(code, lang, lc_data)
      end

      {
        "schema_version" => "3",
        "identifier" => code,
        "status" => "valid",
        "localized_concepts" => localized.keys,
        "data" => {
          "identifier" => code,
          "localized_concepts" => localized,
        },
      }
    end

    def self.build_v3_localized_from_parsed(code, lang, lc_data)
      term_text = lc_data["term"].to_s
      terms = if term_text.empty?
                []
              else
                [{ "type" => "expression", "designation" => term_text, "normative_status" => "preferred" }]
              end

      definition = lc_data["definition"]
      notes_examples = split_notes_examples(definition)

      result = {
        "id" => code,
        "language_code" => lang,
        "terms" => terms,
        "entry_status" => "valid",
      }

      if notes_examples[:definition] && !notes_examples[:definition].empty?
        result["definition"] = [{ "content" => notes_examples[:definition] }]
      end
      result["notes"] = notes_examples[:notes].map { |n| { "content" => n } } if notes_examples[:notes]&.any?
      result["examples"] = notes_examples[:examples].map { |e| { "content" => e } } if notes_examples[:examples]&.any?

      result
    end

    NOTE_RE = %r{<p>\s*Note\s+\d+\s+to\s+entry:.*?</p>}im
    EXAMPLE_RE = %r{<p>\s*Example\s*:\s*(?:</p>\s*<p>)?(.*?)</p>}im
    NOTE_TEXT_RE = /Note\s+\d+\s+to\s+entry:\s*/i

    def self.split_notes_examples(definition_html)
      return { definition: nil, notes: [], examples: [] } unless definition_html

      notes = []
      examples = []

      definition_html.scan(NOTE_RE) do
        note_html = Regexp.last_match[0]
        text = strip_html(note_html).sub(NOTE_TEXT_RE, "").strip
        notes << text
      end

      definition_text = definition_html
        .gsub(NOTE_RE, "")
        .gsub(EXAMPLE_RE) { examples << strip_html(Regexp.last_match[1]).strip; "" }
        .strip
      definition_text = nil if definition_text.empty?

      { definition: definition_text, notes: notes, examples: examples }
    end

    def self.strip_html(html)
      return "" unless html
      html
        .gsub(/<li>/, "\n• ")
        .gsub(/<\/li>/, "")
        .gsub(/<ul>|<\/ul>|<ol>|<\/ol>/, "\n")
        .gsub(/<p>/, "\n")
        .gsub(/<\/p>/, "")
        .gsub(/<i>|<\/i>|<b>|<\/b>|<em>|<\/em>/, "")
        .gsub(/<br\s*\/?>/, "\n")
        .gsub(/<[^>]+>/, "")
        .gsub(/&amp;/, "&")
        .gsub(/&lt;/, "<")
        .gsub(/&gt;/, ">")
        .gsub(/&quot;/, "\"")
        .gsub(/&#39;/, "'")
        .gsub(/\n{3,}/, "\n\n")
        .strip
    end

    # ─── Merge ───

    def self.merge(tb_v3, live_v3, code)
      if tb_v3 && live_v3
        merge_both(tb_v3, live_v3, code)
      elsif tb_v3
        retire_concept(tb_v3, code)
      elsif live_v3
        live_v3
      end
    end

    def self.merge_both(tb_v3, live_v3, code)
      merged = tb_v3.dup
      merged["data"] = Marshal.load(Marshal.dump(tb_v3["data"]))

      live_lc = live_v3["data"]["localized_concepts"]
      tb_lc = merged["data"]["localized_concepts"]

      live_lc.each do |lang, live_entry|
        tb_entry = tb_lc[lang]
        if tb_entry
          merged_lc = merge_localized(tb_entry, live_entry)
          tb_lc[lang] = merged_lc
        else
          tb_lc[lang] = live_entry
        end
      end

      merged["localized_concepts"] = tb_lc.keys

      if content_changed?(tb_v3, live_v3)
        dates = merged["dates"] || []
        dates << { "type" => "amended", "date" => MIRROR_DATE }
        merged["dates"] = dates
      end

      merged
    end

    def self.merge_localized(tb_entry, live_entry)
      result = tb_entry.dup

      live_def = live_entry["definition"]&.first&.dig("content")
      tb_def = tb_entry["definition"]&.first&.dig("content")

      if live_def && (!tb_def || normalize_for_diff(live_def) != normalize_for_diff(tb_def))
        result["definition"] = [{ "content" => live_def }]
      end

      live_terms = live_entry["terms"]
      if live_terms&.any?
        result["terms"] = live_terms
      end

      live_notes = live_entry["notes"]
      result["notes"] = live_notes if live_notes

      live_examples = live_entry["examples"]
      result["examples"] = live_examples if live_examples

      result
    end

    def self.content_changed?(tb_v3, live_v3)
      tb_eng = tb_v3["data"]["localized_concepts"]["eng"]
      live_eng = live_v3["data"]["localized_concepts"]["eng"]
      return false unless tb_eng && live_eng

      tb_def = normalize_for_diff(tb_eng["definition"]&.first&.dig("content").to_s)
      live_def = normalize_for_diff(live_eng["definition"]&.first&.dig("content").to_s)

      tb_def != live_def
    end

    def self.normalize_for_diff(str)
      return "" unless str
      str
        .gsub(/<[^>]+>/, "")
        .gsub(/\s+/, " ")
        .gsub(/["""']/, "'")
        .strip
        .downcase
    end

    def self.retire_concept(tb_v3, code)
      retired = Marshal.load(Marshal.dump(tb_v3))
      retired["status"] = "retired"
      dates = retired["dates"] || []
      dates << { "type" => "retired", "date" => MIRROR_DATE }
      retired["dates"] = dates
      retired
    end
  end
end

# ─── Main ───

options = { output: File.join(REPO_ROOT, "tmp", "reconciled"), limit: nil }
OptionParser.new { |opts|
  opts.on("--output DIR") { |v| options[:output] = v }
  opts.on("--limit N", Integer) { |v| options[:limit] = v }
}.parse!

TERMBASE_PATH = File.expand_path("../iev-data/termbase.yaml", REPO_ROOT)
PAGES_DIR = File.expand_path("../iev-data-latest", REPO_ROOT)

warn "Loading termbase from #{TERMBASE_PATH}..."
termbase = YAML.load_file(TERMBASE_PATH)
warn "  #{termbase.size} concepts in termbase"

warn "Loading live HTML from #{PAGES_DIR}..."
pages_dir = File.join(PAGES_DIR, "pages")
live_concepts = {}
count = 0
Dir.glob(File.join(pages_dir, "*.html")).sort.each do |path|
  code = File.basename(path, ".html")
  html = File.read(path, encoding: "utf-8")
  doc = Nokogiri::HTML(html)
  parsed = Iev::Scraper::PageParser.new(doc, code).parse rescue nil
  if parsed && parsed.dig("data", "localized_concepts")&.any?
    live_concepts[code] = parsed
  end
  count += 1
  break if options[:limit] && count >= options[:limit]
end
warn "  #{live_concepts.size} live concepts parsed (from #{count} pages)"

warn "Reconciling..."
all_codes = (termbase.keys + live_concepts.keys).map(&:to_s).uniq.sort
stats = { in_both: 0, termbase_only: 0, live_only: 0, amended: 0 }

output_concepts_dir = File.join(options[:output], "concepts")
FileUtils.mkdir_p(output_concepts_dir)

all_codes.each_with_index do |code, idx|
  tb_entry = termbase[code] || termbase[code.to_s]
  live_raw = live_concepts[code]

  tb_v3 = tb_entry ? Iev::Reconciler.termbase_to_v3(code, tb_entry) : nil
  live_v3 = live_raw ? Iev::Reconciler.live_to_v3(code, live_raw) : nil

  merged = Iev::Reconciler.merge(tb_v3, live_v3, code)
  next unless merged

  if tb_v3 && live_v3
    stats[:in_both] += 1
    stats[:amended] += 1 if Iev::Reconciler.content_changed?(tb_v3, live_v3)
  elsif tb_v3
    stats[:termbase_only] += 1
  else
    stats[:live_only] += 1
  end

  File.write(
    File.join(output_concepts_dir, "concept-#{code}.yaml"),
    YAML.dump(merged),
  )

  if (idx + 1) % 2000 == 0
    warn "  #{idx + 1}/#{all_codes.size}..."
  end
end

warn ""
warn "Results:"
warn "  In both (merged):     #{stats[:in_both]}"
warn "  Termbase only (retired): #{stats[:termbase_only]}"
warn "  Live only (new):      #{stats[:live_only]}"
warn "  Amendments detected:  #{stats[:amended]}"
warn "  Total:                #{all_codes.size}"
warn ""
warn "Output: #{options[:output]}"
