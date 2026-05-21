# frozen_string_literal: true

module Iev
  # Creates ManagedConcept entries for the IEV subject area hierarchy.
  #
  # The hierarchy has two levels:
  #   - Area (e.g., "102" = "Mathematics - General concepts")
  #   - Section (e.g., "102-01" = "Sets and operations")
  #
  # Linking (all at ManagedConcept#related level):
  #   - Each area has "narrower" relations to its sections
  #   - Each section has "broader" relation to parent area
  #   - Each section gets "narrower" to child concepts (added by Exporter)
  #   - Each regular IEV concept gets "broader" to its section
  #     (added by Exporter)
  #
  # Classification (separate from hierarchy):
  #   - Each concept's ManagedConceptData#domains includes area and
  #     section ConceptReferences
  #   - Each concept's ConceptData#domain references its section URI
  #   - Each section concept's ConceptData#domain references parent area
  module SubjectAreaConcepts
    IEV_SOURCE = "urn:iec:std:iec:60050"

    class << self
      # Build all area and section concepts and add them to the collection.
      #
      # @param collection [Glossarist::ManagedConceptCollection]
      # @return [void]
      def add_to(collection)
        Iev.subject_areas.each do |area|
          area_mc = build_area_concept(area)
          collection.store(area_mc)

          area.sections.each do |section|
            section_mc = build_section_concept(section, area)
            collection.store(section_mc)
          end
        end
      end

      private

      def domain_ref(concept_id)
        Glossarist::ConceptReference.new(
          concept_id: concept_id,
          source: IEV_SOURCE,
          ref_type: "domain",
        )
      end

      def build_area_concept(area)
        id = area.uri

        mc = Glossarist::ManagedConcept.new(
          data: Glossarist::ManagedConceptData.new(
            id: id,
            domains: [domain_ref(id)],
          ),
        )
        mc.uuid = id

        mc.add_localization(build_localization(id, area.title, "eng"))
        mc.related = area.sections.map { |s| build_narrower_relation(s.uri) }
        mc.related = nil if mc.related.empty?

        mc
      end

      def build_section_concept(section, area)
        id = section.uri

        mc = Glossarist::ManagedConcept.new(
          data: Glossarist::ManagedConceptData.new(
            id: id,
            domains: [
              domain_ref(area.uri),
              domain_ref(id),
            ],
          ),
        )
        mc.uuid = id

        cd = build_concept_data(id, section.title, "eng")
        cd.domain = area.uri

        mc.add_localization(build_localization_from_data(id, cd))

        mc.related = [build_broader_relation(area.uri)]

        mc
      end

      def build_concept_data(id, title, lang_code)
        Glossarist::ConceptData.new(
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
      end

      def build_localization(id, title, lang_code)
        cd = build_concept_data(id, title, lang_code)

        l10n = Glossarist::LocalizedConcept.new
        l10n.data = cd
        l10n.id = id
        l10n.entry_status = "valid"
        l10n.data.review_decision_event = "published"
        l10n
      end

      def build_localization_from_data(id, concept_data)
        l10n = Glossarist::LocalizedConcept.new
        l10n.data = concept_data
        l10n.id = id
        l10n.entry_status = "valid"
        l10n.data.review_decision_event = "published"
        l10n
      end

      def build_broader_relation(target_uri)
        Glossarist::RelatedConcept.new(
          type: "broader",
          content: target_uri,
          ref: Glossarist::Citation.new(source: "IEV", id: target_uri),
        )
      end

      def build_narrower_relation(target_uri)
        Glossarist::RelatedConcept.new(
          type: "narrower",
          content: target_uri,
          ref: Glossarist::Citation.new(source: "IEV", id: target_uri),
        )
      end
    end
  end
end
