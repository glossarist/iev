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
  #   - Each concept's ManagedConceptData#domains includes domain and
  #     section ConceptReferences (per ConceptReferenceType)
  #   - Each section concept's ConceptData#domain references parent area
  #     title text (a LocalizedString, not a URI)
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

          area.sections.each do |section|
            section_mc = build_section_concept(section, area)
            collection.store(section_mc)
          end
        end
      end

      private

      def build_area_concept(area)
        id = area.uri

        mc = Glossarist::ManagedConcept.new(
          data: Glossarist::ManagedConceptData.new(
            id: id,
            domains: [domain_ref(id)],
            tags: [area.title],
          ),
        )
        mc.uuid = id
        mc.schema_version = "3"

        mc.add_localization(
          build_localization(id, build_concept_data(id, area.title, "eng")),
        )
        mc.related = area.sections.map { |s| narrower_relation(s.uri) }
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
              section_ref(id),
            ],
            tags: [area.title, section.title],
          ),
        )
        mc.uuid = id
        mc.schema_version = "3"

        cd = build_concept_data(id, section.title, "eng")
        # ConceptData#domain is a LocalizedString — use the area title text,
        # not a URI. The structural relationship is expressed via domains[]
        # and related[].
        cd.domain = area.title

        mc.add_localization(build_localization(id, cd))
        mc.related = [broader_relation(area.uri)]

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

      def build_localization(id, concept_data)
        l10n = Glossarist::LocalizedConcept.new
        l10n.data = concept_data
        l10n.id = id
        l10n.entry_status = "valid"
        l10n.data.review_decision_event = "published"
        l10n
      end

      # --- ConceptReference factory methods ---

      def domain_ref(concept_id)
        ref = Glossarist::ConceptReference.domain(concept_id)
        ref.source = IEV_SOURCE
        ref
      end

      def section_ref(concept_id)
        ref = Glossarist::ConceptReference.section(concept_id)
        ref.source = IEV_SOURCE
        ref
      end

      # --- RelatedConcept factory methods ---

      def broader_relation(target_uri)
        Glossarist::RelatedConcept.new(
          type: "broader",
          content: target_uri,
          ref: Glossarist::ConceptRef.new(source: "IEV", id: target_uri),
        )
      end

      def narrower_relation(target_uri)
        Glossarist::RelatedConcept.new(
          type: "narrower",
          content: target_uri,
          ref: Glossarist::ConceptRef.new(source: "IEV", id: target_uri),
        )
      end
    end
  end
end
