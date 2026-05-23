# frozen_string_literal: true

require "spec_helper"

RSpec.describe Iev::SubjectAreaConcepts do
  let(:area) do
    Iev::SubjectArea.new(
      code: "103",
      title: "Mathematics - Functions",
      sections: [
        Iev::Section.new(code: "103-01", title: "General functions",
                         area_code: "103"),
        Iev::Section.new(code: "103-02", title: "Special functions",
                         area_code: "103"),
      ],
    )
  end

  let(:area_without_sections) do
    Iev::SubjectArea.new(code: "999", title: "Empty area")
  end

  before do
    allow(Iev).to receive(:subject_areas).and_return([area])
  end

  describe ".add_to" do
    let(:collection) { Glossarist::ManagedConceptCollection.new }

    it "adds area and section concepts to the collection" do
      described_class.add_to(collection)
      ids = collection.map { |c| c.data.id }
      expect(ids).to include("area-103", "section-103-01", "section-103-02")
    end

    it "returns the correct count (1 area + 2 sections)" do
      described_class.add_to(collection)
      expect(collection.count).to eq(3)
    end
  end

  describe "area concept structure" do
    let(:collection) { Glossarist::ManagedConceptCollection.new }

    before { described_class.add_to(collection) }

    subject(:area_concept) do
      collection.find { |c| c.data.id == "area-103" }
    end

    it "has domain reference to itself with IEC URN source" do
      expect(area_concept.data.domains.length).to eq(1)
      d = area_concept.data.domains.first
      expect(d.concept_id).to eq("area-103")
      expect(d.source).to eq("urn:iec:std:iec:60050")
      expect(d.ref_type).to eq("domain")
    end

    it "has an English localization with the area title" do
      l10n = area_concept.localization("eng")
      expect(l10n).not_to be_nil
      expect(l10n.data.terms.first.designation).to eq("Mathematics - Functions")
    end

    it "has narrower relations to its sections" do
      expect(area_concept.related.length).to eq(2)
      expect(area_concept.related.map(&:type)).to eq(%w[narrower narrower])
      expect(area_concept.related.map(&:content)).to eq(%w[section-103-01
                                                           section-103-02])
    end

    it "sets ref on narrower relations for RDF transform" do
      area_concept.related.each do |rel|
        expect(rel.ref).to be_a(Glossarist::ConceptRef)
        expect(rel.ref.source).to eq("IEV")
        expect(rel.ref.id).to eq(rel.content)
      end
    end

    it "has valid entry status" do
      l10n = area_concept.localization("eng")
      expect(l10n.data.entry_status).to eq("valid")
    end

    it "has review_decision_event set to published" do
      l10n = area_concept.localization("eng")
      expect(l10n.data.review_decision_event).to eq("published")
    end
  end

  describe "section concept structure" do
    let(:collection) { Glossarist::ManagedConceptCollection.new }

    before { described_class.add_to(collection) }

    subject(:section_concept) do
      collection.find { |c| c.data.id == "section-103-01" }
    end

    it "has domain references with IEC URN source" do
      domain_ids = section_concept.data.domains.map(&:concept_id)
      expect(domain_ids).to eq(%w[area-103 section-103-01])
      section_concept.data.domains.each do |d|
        expect(d.source).to eq("urn:iec:std:iec:60050")
        expect(d.ref_type).to eq("domain")
        expect(d).to be_a(Glossarist::ConceptReference)
      end
    end

    it "has an English localization with the section title" do
      l10n = section_concept.localization("eng")
      expect(l10n).not_to be_nil
      expect(l10n.data.terms.first.designation).to eq("General functions")
    end

    it "has a broader relation at ManagedConcept level" do
      expect(section_concept.related.length).to eq(1)
      rel = section_concept.related.first
      expect(rel.type).to eq("broader")
      expect(rel.content).to eq("area-103")
    end

    it "sets ref on broader relation for RDF transform" do
      rel = section_concept.related.first
      expect(rel.ref).to be_a(Glossarist::ConceptRef)
      expect(rel.ref.source).to eq("IEV")
      expect(rel.ref.id).to eq("area-103")
    end

    it "has domain on ConceptData pointing to parent area" do
      l10n = section_concept.localization("eng")
      expect(l10n.data.domain).to eq("area-103")
    end
  end

  describe "area without sections" do
    let(:collection) { Glossarist::ManagedConceptCollection.new }

    before do
      allow(Iev).to receive(:subject_areas).and_return([area_without_sections])
      described_class.add_to(collection)
    end

    it "creates the area concept" do
      expect(collection.count).to eq(1)
      expect(collection.first.data.id).to eq("area-999")
    end

    it "has no related concepts" do
      expect(collection.first.related).to be_nil
    end
  end
end
