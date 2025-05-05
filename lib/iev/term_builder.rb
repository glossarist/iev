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

      Glossarist::LocalizedConcept.from_hash(term_hash)
    end

    def term_hash
      dates = nil

      if flesh_date(find_value_for("PUBLICATIONDATE"))
        dates = [
          {
            type: :accepted,
            date: flesh_date(find_value_for("PUBLICATIONDATE")),
          },
          {
            type: :amended,
            date: flesh_date(find_value_for("PUBLICATIONDATE")),
          },
        ]
      end

      {
        id: term_id,
        classification: extract_classification,
        entry_status: extract_entry_status,
        data: {
          id: term_id,
          dates: dates,
          definition: [{ "content" => extract_definition_value }],
          examples: extract_examples,
          notes: extract_notes,
          terms: extract_terms,
          review_date: flesh_date(find_value_for("PUBLICATIONDATE")),
          review_decision_date: flesh_date(find_value_for("PUBLICATIONDATE")),
          review_decision_event: "published",
          language_code: term_language,
          sources: extract_authoritative_source,
          related: extract_superseded_concepts,
        }.compact,
      }.compact
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
            Note\s*\d+?\sà\sl['’]article: |
            <NOTE/?>?\s*\d?\s+.*?– |
            NOTE(?:\s+-)? |
            Note\s+\d+\s– |
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
        next_part.sub!(/^\[:Ex(a|e)mple\]/, 'Ex\\1mple')
        next_part_arr.push(next_part)
        next_part_arr = md[:example] ? @examples : @notes
        # 112-03-17
        # supplements the name of a quantity, especially for a component in a
        # system, to indicate the quotient of that quantity by the total
        # volume
        # <NOTE – Examples: amount-of-substance volume concentration of
        # component B (or concentration of B, in particular, ion
        # concentration), molecular concentration of B, electron concentration
        # (or electron density).
        #
        # In the above case the `Example` is part of the note but the regex
        # above will capture it as an example and will add an empty `Note`
        # and put the rest in an `Example`. So In this case we will replace
        # the `Example` with `[:Example]` and revert it in the next iteration
        # so it will not be caught by the regex.
        remaining_str = md.post_match
        remaining_str.sub!(/^Ex(a|e)mple/, '[:Ex\\1mple]') if md[:note]
      end

      remaining_str&.sub!(/^\[:Ex(a|e)mple\]/, 'Ex\\1mple')
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

      Iev::Converter.mathml_to_asciimath(
        replace_newlines(parse_anchor_tag(@definition, term_domain)),
      ).strip
    end

    def extract_examples
      @examples.map do |str|
        {
          content: Iev::Converter.mathml_to_asciimath(
            replace_newlines(parse_anchor_tag(str, term_domain)),
          ).strip,
        }
      end
    end

    def extract_notes
      @notes.map do |str|
        {
          content: Iev::Converter.mathml_to_asciimath(
            replace_newlines(parse_anchor_tag(str, term_domain)),
          ).strip,
        }
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
      when ""
        "admitted"
      when "认可的", "допустимый", "admitido"
        "admitted"
      when "首选的", "suositettava", "suositeltava", "рекомендуемый", "preferente"
        "preferred"
      else
        classification_val
      end
    end

    def extract_authoritative_source
      source_val = find_value_for("SOURCE")
      return nil if source_val.nil?

      SourceParser.new(source_val, term_domain)
        .parsed_sources
        .compact
        .map do |source|
        source.merge({ "type" => "authoritative" })
      end
    end

    def extract_superseded_concepts
      replaces_val = find_value_for("REPLACES")
      return nil if replaces_val.nil?

      SupersessionParser.new(replaces_val).supersessions
    end

    private

    def build_expression_designation(raw_term, attribute_data:, status:)
      term = Iev::Converter.mathml_to_asciimath(
        parse_anchor_tag(raw_term, term_domain),
      )
      term_attributes = TermAttrsParser.new(attribute_data.to_s)

      statuses = {
        "obsoleto" => "deprecated",
        "напуштен" => "deprecated",
      }

      {
        "type" => "expression",
        "prefix" => term_attributes.prefix,
        "normative_status" => statuses[status] || status,
        "usage_info" => term_attributes.usage_info,
        "designation" => term,
        "part_of_speech" => term_attributes.part_of_speech,
        "geographical_area" => term_attributes.geographical_area,
        "gender" => term_attributes.gender,
        "plurality" => term_attributes.plurality,
      }.compact
    end

    def build_symbol_designation(raw_term)
      term = Iev::Converter.mathml_to_asciimath(
        parse_anchor_tag(raw_term, term_domain),
      )

      {
        "type" => "symbol",
        "designation" => term,
        "international" => true,
      }.compact
    end
  end
end
