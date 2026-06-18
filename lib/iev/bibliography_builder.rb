# frozen_string_literal: true

module Iev
  # Builds a `Glossarist::BibliographyData` from the sources cited across a
  # concept collection.
  #
  # Each unique `(source, id)` pair from a concept's `ConceptSource#origin`
  # becomes one `BibliographyEntry`. The entry's `id` is the normalized
  # anchor that `Glossarist::Validation::BibliographyIndex` uses for
  # resolution — so the same normalization rules are applied here.
  module BibliographyBuilder
    module_function

    # @param concepts [Enumerable<Glossarist::ManagedConcept>]
    # @return [Glossarist::BibliographyData]
    def build(concepts)
      entries = collect_entries(concepts)
      Glossarist::BibliographyData.new(entries: entries)
    end

    def collect_entries(concepts)
      seen = {}
      concepts.each do |concept|
        concept.localizations.each do |l10n|
          collect_from_l10n(l10n, seen)
        end
        Array(concept.sources).each { |src| add_source_entry(src, seen) }
      end
      seen.values.sort_by(&:id)
    end
    private_class_method :collect_entries

    def collect_from_l10n(l10n, seen)
      Array(l10n.all_sources).each { |src| add_source_entry(src, seen) }
    end
    private_class_method :collect_from_l10n

    def add_source_entry(source, seen)
      ref = source_origin_ref(source)
      return unless ref

      seen[entry_label(ref)] ||= build_entry(ref, source&.origin)
    end
    private_class_method :add_source_entry

    def source_origin_ref(source)
      ref = source&.origin&.ref
      return unless ref&.source && !ref.source.strip.empty?

      ref
    end
    private_class_method :source_origin_ref

    def build_entry(ref, origin)
      label = entry_label(ref)
      Glossarist::BibliographyEntry.new(
        id: normalize_anchor(label),
        reference: label,
        link: origin&.link,
        type: type_for(ref.source),
      )
    end
    private_class_method :build_entry

    def entry_label(ref)
      [ref.source, ref.id].compact.join(" ").strip
    end
    private_class_method :entry_label

    # Mirrors `Glossarist::Validation::BibliographyIndex#normalize_anchor`
    # so the id we write matches what the validator will look up.
    def normalize_anchor(anchor)
      anchor.to_s.gsub(/[ \/:]/, "_").gsub(/__+/, "_").downcase
    end
    private_class_method :normalize_anchor

    def type_for(source)
      case source.to_s
      when /\A(IEV|VIM|JCGM)/ then "vocabulary"
      when /\AITU/ then "recommendation"
      when /\A(BIPM|BBIPM)/ then "brochure"
      else "standard"
      end
    end
    private_class_method :type_for
  end
end
