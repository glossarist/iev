# frozen_string_literal: true

module Iev
  # Creates ManagedConcept entries for the IEV subject area hierarchy.
  #
  # The hierarchy has two levels:
  #   - Area (e.g., "102" = "Mathematics - General concepts and linear algebra")
  #   - Section (e.g., "102-01" = "Sets and operations")
  #
  # Linking:
  #   - Each IEV concept's ConceptData#domain references its section URI
  #   - Each IEV concept's ManagedConceptData#domains includes area and section codes
  #   - Each section concept has a "broader" relation to its parent area
  #   - Each area concept has "narrower" relations to its sections
  module SubjectAreaConcepts
    class << self
      # Build all area and section concepts and add them to the collection.
      #
      # @param collection [Glossarist::ManagedConceptCollection]
      # @return [void]
      def add_to(collection)
        Iev.subject_areas.each do |area|
          area_mc = build_area_concept(area)
          collection.store(area_mc)

          (area["sections"] || []).each do |section|
            section_mc = build_section_concept(section, area)
            collection.store(section_mc)
          end
        end
      end

      private

      def build_area_concept(area)
        id = SubjectAreas.area_uri(area["code"])

        mc = Glossarist::ManagedConcept.new(
          data: Glossarist::ManagedConceptData.new(
            id: id,
            domains: [Glossarist::ConceptReference.domain(id)],
          ),
        )

        mc.add_localization(build_localization(id, area["title"], "eng"))

        narrower = (area["sections"] || []).map { |s| build_narrower_ref(s["code"]) }
        mc.related = narrower unless narrower.empty?

        mc
      end

      def build_section_concept(section, area)
        id = SubjectAreas.section_uri(section["code"])

        mc = Glossarist::ManagedConcept.new(
          data: Glossarist::ManagedConceptData.new(
            id: id,
            domains: [
              Glossarist::ConceptReference.domain(SubjectAreas.area_uri(area["code"])),
              Glossarist::ConceptReference.domain(id),
            ],
          ),
        )

        cd = build_concept_data(id, section["title"], "eng")
        cd.domain = SubjectAreas.area_uri(area["code"])
        cd.related = [build_broader_ref(area["code"])]

        mc.add_localization(build_localization_from_data(id, cd))
        mc
      end

      def build_localization(id, title, lang_code)
        cd = build_concept_data(id, title, lang_code)

        l10n = Glossarist::LocalizedConcept.new(data: cd)
        l10n.id = id
        l10n
      end

      def build_localization_from_data(id, concept_data)
        l10n = Glossarist::LocalizedConcept.new(data: concept_data)
        l10n.id = id
        l10n
      end

      def build_concept_data(id, title, lang_code)
        cd = Glossarist::ConceptData.new(
          id: id,
          language_code: lang_code,
          terms: [
            Glossarist::Designation::Expression.new(
              type: "expression",
              designation: title,
              normative_status: "preferred",
            ),
          ],
        )
        cd.entry_status = "valid"
        cd.review_decision_event = "published"
        cd
      end

      def build_broader_ref(area_code)
        Glossarist::RelatedConcept.new(
          type: "broader",
          content: SubjectAreas.area_uri(area_code),
        )
      end

      def build_narrower_ref(section_code)
        Glossarist::RelatedConcept.new(
          type: "narrower",
          content: SubjectAreas.section_uri(section_code),
        )
      end
    end
  end
end
