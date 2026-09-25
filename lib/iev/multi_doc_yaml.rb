# frozen_string_literal: true

require "fileutils"

module Iev
  # Assembles serialized glossarist models into valid multi-document YAML.
  #
  # Lutaml::Model versions below 0.8.30 emit `to_yaml` without the leading
  # "---" document start marker. Concatenating such outputs naively (as
  # glossarist's `save_grouped_concepts_to_files` does with `join("\n")`)
  # merges all documents into one YAML mapping, with later keys overriding
  # earlier ones — the last localized concept would silently replace the
  # managed concept's data. `join` guarantees each part is a self-contained
  # YAML document and is a no-op for outputs that already carry the marker.
  module MultiDocYaml
    DOCUMENT_START = "---"

    module_function

    # Serialized YAML documents for a managed concept: the concept first,
    # then each of its localizations (glossarist's grouped file layout).
    def parts_for(concept)
      [concept.to_yaml].tap do |parts|
        (concept.localized_concepts || {}).each_key do |lang|
          l10n = concept.localization(lang)
          parts << l10n.to_yaml if l10n
        end
      end
    end

    # Concatenates serialized YAML parts into a parseable document stream.
    def join(parts)
      parts.map { |part| with_document_start(part) }.join("\n")
    end

    # Writes joined parts to +path+ as UTF-8.
    def write(path, parts)
      File.write(path, join(parts), encoding: "utf-8")
    end

    # Writes one grouped YAML file per managed concept (concept followed by
    # its localizations) into +dir+, named by the concept's uuid — the same
    # layout and naming as glossarist's `save_grouped_concepts_to_files`,
    # but document-marker-safe.
    def save_grouped_concepts(collection, dir)
      FileUtils.mkdir_p(dir)

      collection.each do |concept|
        write(File.join(dir.to_s, "#{concept.uuid}.yaml"), parts_for(concept))
      end
    end

    # Prepends the YAML document start marker unless already present.
    def with_document_start(yaml)
      return yaml if yaml.start_with?(DOCUMENT_START)

      "#{DOCUMENT_START}\n#{yaml}"
    end
  end
end
