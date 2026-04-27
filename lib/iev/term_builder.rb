# frozen_string_literal: true

# (c) Copyright 2020 Ribose Inc.
#

module Iev
  class TermBuilder
    include Cli::Ui
    include Utilities
    using DataConversions

    def initialize(data)
      @data = data
    end

    def build
      build_term_object
    end

    def self.build_from(data)
      new(data).build
    end

    attr_reader :data

    def find_value_for(key)
      data.fetch(key.to_sym, nil)&.sanitize
    end

    def flesh_date(incomplete_date)
      return incomplete_date if incomplete_date.nil? || incomplete_date.empty?

      year, month, day = incomplete_date.split("-")

      month ||= "01"
      day ||= "01"

      DateTime.parse("#{year}-#{month}-#{day}").to_s
    end

    def build_term_object
      set_ui_tag "#{term_id} (#{term_language})"
      progress "Processing term #{term_id} (#{term_language})..."

      split_definition

      concept_data = build_concept_data

      concept = Glossarist::LocalizedConcept.new
      concept.data = concept_data
      concept.id = term_id
      concept.entry_status = extract_entry_status
      concept.classification = extract_classification

      concept
    end

    def build_concept_data
      cd = Glossarist::ConceptData.new
      cd.id = term_id
      cd.language_code = term_language

      pub_date = flesh_date(find_value_for("PUBLICATIONDATE"))
      if pub_date
        cd.dates = [
          Glossarist::ConceptDate.new(type: "accepted", date: pub_date),
          Glossarist::ConceptDate.new(type: "amended", date: pub_date),
        ]
        cd.review_date = pub_date
        cd.review_decision_date = pub_date
      end
      cd.review_decision_event = "published"

      definition = extract_definition_value
      cd.definition = [definition] if definition
      cd.examples = extract_examples
      cd.notes = extract_notes
      cd.terms = extract_terms

      sources = extract_authoritative_source
      cd.sources = sources if sources&.any?

      related = extract_superseded_concepts
      cd.related = related if related&.any?

      cd
    end

    def term_id
      @term_id ||= find_value_for("IEVREF")
    end

    def term_domain
      @term_domain ||= term_id.slice(0, 3)
    end

    def term_language
      @term_language ||= find_value_for("LANGUAGE").to_three_char_code
    end

    # Splits unified definition (from the spreadsheet) into separate
    # definition, examples, and notes strings (for YAMLs).
    #
    # Sets +@definition+, +@examples+ and +@notes+ variables.
    def split_definition
      slicer_rx = %r{
        \s*
        (?:<p>\s*)?
        (
          (?<example>
            # English example
            \bEXAMPLE\b |
            ^\bExamples\s+are\b: |
            ^\bExamples\b: |
            ^\bExample\b: |
            # French examples
            \bEXEMPLE\b |
            ^\bExemples\b:
          )
          |
          (?<note>
            Note\s*\d+\sto\sentry: |
            Note&nbsp;\d+\sto\sentry: |
            Note\s*\d+\sto\sthe\sentry: |
            Note\sto\sentry\s*\d+: |
            Note\s*\d+?\sà\sl['']article: |
            <NOTE/?>?\s*\d?\s+[–-]\s* |
            NOTE(?:\s+-)?\s* |
            Note\s+\d+\s[–-]\s* |
            Note&nbsp;\d+\s
          )
        )
        \s*
      }x

      @examples = []
      @notes = []
      definition_arr = [] # here array for consistent interface

      next_part_arr = definition_arr
      remaining_str = find_value_for("DEFINITION")

      while (md = remaining_str&.match(slicer_rx))
        next_part = md.pre_match
        next_part.sub!(/^\[:Ex(a|e)mple\]/, 'Ex\1mple')
        next_part_arr.push(next_part)
        next_part_arr = md[:example] ? @examples : @notes
        remaining_str = md.post_match
        remaining_str.sub!(/^Ex(a|e)mple/, '[:Ex\1mple]') if md[:note]
      end

      remaining_str&.sub!(/^\[:Ex(a|e)mple\]/, 'Ex\1mple')
      next_part_arr.push(remaining_str)
      @definition = definition_arr.first
      @definition = nil if @definition&.empty?
    end

    def extract_terms
      [
        extract_primary_designation,
        *extract_synonymous_designations,
        extract_international_symbol_designation,
      ].compact
    end

    def extract_primary_designation
      raw_term = find_value_for("TERM")
      raw_term = "NA" if raw_term == "....."

      build_expression_designation(
        raw_term,
        attribute_data: find_value_for("TERMATTRIBUTE"),
        status: "preferred",
      )
    end

    def extract_synonymous_designations
      retval = (1..3).map do |num|
        designations = find_value_for("SYNONYM#{num}") || ""

        # Some synonyms have more than one entry
        designations.split(/<[pbr]+>/).map do |raw_term|
          build_expression_designation(
            raw_term,
            attribute_data: find_value_for("SYNONYM#{num}ATTRIBUTE"),
            status: find_value_for("SYNONYM#{num}STATUS")&.downcase,
          )
        end
      end

      retval.flatten.compact
    end

    def extract_international_symbol_designation
      raw_term = find_value_for("SYMBOLE")
      raw_term && build_symbol_designation(raw_term)
    end

    def extract_definition_value
      return unless @definition

      content = convert_content(@definition)
      Glossarist::DetailedDefinition.new(content: content)
    end

    def extract_examples
      @examples.map do |str|
        content = convert_content(clean_extracted_text(str))
        Glossarist::DetailedDefinition.new(content: content)
      end
    end

    def extract_notes
      @notes.map do |str|
        content = convert_content(clean_extracted_text(str))
        Glossarist::DetailedDefinition.new(content: content)
      end
    end

    def extract_entry_status
      case find_value_for("STATUS").downcase
      when "standard" then "valid"
      end
    end

    def extract_classification
      classification_val = find_value_for("SYNONYM1STATUS")

      case classification_val
      when nil, ""
        nil
      when "认可的", "допустимый", "admitido"
        "admitted"
      when "首选的", "suositettava", "suositeltava", "рекомендуемый", "preferente"
        "preferred"
      else
        classification_val.downcase
      end
    end

    def extract_authoritative_source
      source_val = find_value_for("SOURCE")
      return nil if source_val.nil?

      sources = SourceParser.new(source_val, term_domain)
        .parsed_sources
        .compact

      sources.each { |src| src.type = "authoritative" }
      sources.empty? ? nil : sources
    end

    def extract_superseded_concepts
      replaces_val = find_value_for("REPLACES")
      return nil if replaces_val.nil?

      SupersessionParser.new(replaces_val).supersessions
    end

    private

    def build_expression_designation(raw_term, attribute_data:, status:)
      term = convert_content(raw_term)
      term_attributes = TermAttrsParser.new(attribute_data.to_s)

      statuses = {
        "obsoleto" => "deprecated",
        "напуштен" => "deprecated",
      }

      grammar_info = term_attributes.to_grammar_info
      attrs = {
        designation: term,
        normative_status: statuses[status] || status,
        geographical_area: term_attributes.geographical_area,
        prefix: term_attributes.prefix,
        usage_info: term_attributes.usage_info,
        grammar_info: grammar_info ? [grammar_info] : nil,
      }.compact

      Glossarist::Designation::Expression.new(**attrs)
    end

    def build_symbol_designation(raw_term)
      term = convert_content(raw_term)

      Glossarist::Designation::Symbol.new(
        designation: term,
        international: true,
      )
    end

    def convert_content(str)
      stripped = strip_html_comments(str.to_s)
      Iev::Converter.mathml_to_asciimath(
        replace_newlines(parse_anchor_tag(stripped, term_domain)),
      ).strip
    end

    def strip_html_comments(str)
      doc = Nokogiri::HTML::DocumentFragment.parse(str)
      comments = doc.children.select(&:comment?)
      return str if comments.empty?

      result = str.dup
      comments.each { |c| result = result.gsub("<!--#{c.content}-->", "") }
      result
    end

    # Remove leading numbering artifacts from extracted notes/examples.
    # The definition text sometimes duplicates note/example numbers:
    #   "1  A time interval comprises..." (note)
    #   "1: In a vending machine..." (example)
    #   "2 à l'article: ..." (French note)
    #   ": Par la réticulation..." (French note)
    def clean_extracted_text(str)
      # Strip leading number + optional separator (colon, em-space, etc.)
      str.gsub(/\A\s*\d+[\s: ]*\s*/, "")
        # Strip leading standalone colon (French style: ": text")
        .gsub(/\A\s*:\s*/, "")
    end
  end
end
