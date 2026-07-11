# frozen_string_literal: true

module Iev
  module Reconciler
    # Extracts grammatical gender and plurality markers that are inline
    # in Electropedia's live HTML term text (e.g. "Gleichheit, f" or
    # "једнакост, ж јд") and separates them from the designation.
    #
    # This mirrors how the termbase stores the same data: designation
    # without markers, gender and plurality in separate fields.
    #
    # Pattern examples:
    #   "Gleichheit, f"       → designation: "Gleichheit", gender: "f"
    #   "ensemble, m"         → designation: "ensemble", gender: "m"
    #   "једнакост, ж јд"     → designation: "једнакост", gender: "ж", plurality: "јд"
    #   "przestrzeń, m"       → designation: "przestrzeń", gender: "m"
    class TermMarkerParser
      WESTERN_GENDER_RE = /,\s*([fmn])\s*\z/
      SERBIAN_GENDER_PLURAL_RE = /,\s*([жмс])\s+(јд|мн)\s*\z/

      Result = Struct.new(:designation, :gender, :plurality, keyword_init: true)

      class << self
        def parse(term)
          return Result.new(designation: term) unless term

          cleaned = term.strip.gsub(/\s+/, " ")
          if (m = cleaned.match(SERBIAN_GENDER_PLURAL_RE))
            Result.new(
              designation: cleaned[0, m.begin(0)].strip,
              gender: m[1],
              plurality: m[2],
            )
          elsif (m = cleaned.match(WESTERN_GENDER_RE))
            Result.new(
              designation: cleaned[0, m.begin(0)].strip,
              gender: m[1],
            )
          else
            Result.new(designation: cleaned)
          end
        end
      end
    end
  end
end
