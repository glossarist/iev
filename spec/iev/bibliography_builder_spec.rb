# frozen_string_literal: true

require "spec_helper"

RSpec.describe Iev::BibliographyBuilder do
  let(:concept_with_sources) do
    build_concept("103-01-01") do |l10n|
      l10n.data.sources = [
        build_source(source: "IEV", id: "103-01-01"),
        build_source(source: "IEC", id: "60050-103:2009", clause: "103-01"),
      ]
    end
  end

  let(:concept_with_vim_source) do
    build_concept("103-01-02") do |l10n|
      l10n.data.sources = [
        build_source(source: "VIM", id: "JCGM 100:2008", link: "https://www.bipm.org"),
      ]
    end
  end

  describe ".build" do
    it "collects unique bibliography entries across concepts" do
      concepts = [concept_with_sources, concept_with_vim_source]
      bibliography = described_class.build(concepts)

      entries = bibliography.entries
      expect(entries.length).to eq(3)
      expect(entries.map(&:id)).to all(be_a(String))
    end

    it "deduplicates entries with the same source+id" do
      other = build_concept("103-01-03") do |l10n|
        l10n.data.sources = [
          build_source(source: "IEV", id: "103-01-01"),
        ]
      end
      concepts = [concept_with_sources, other]
      bibliography = described_class.build(concepts)

      iev_entries = bibliography.entries.select do |e|
        e.reference.start_with?("IEV")
      end
      expect(iev_entries.length).to eq(1)
    end

    it "preserves entries from localized concept sources" do
      concepts = [concept_with_sources]
      bibliography = described_class.build(concepts)

      expect(bibliography.entries.length).to eq(2)
      bibliography.entries.each do |entry|
        expect(entry.id).to be_a(String)
        expect(entry.id).not_to be_empty
      end
    end

    it "assigns vocabulary type for IEV source" do
      concept = build_concept("103-01-10") do |l10n|
        l10n.data.sources = [build_source(source: "IEV", id: "103-01-10")]
      end

      type = described_class.build([concept]).entries.first.type
      expect(type).to eq("vocabulary")
    end

    it "assigns vocabulary type for VIM/JCGM source" do
      concepts = [concept_with_vim_source]
      bibliography = described_class.build(concepts)

      type = bibliography.entries.first.type
      expect(type).to eq("vocabulary")
    end

    it "returns an empty bibliography for empty concepts list" do
      bibliography = described_class.build([])
      expect(bibliography.entries).to be_empty
    end

    it "returns an empty bibliography when concepts have no sources" do
      concept = build_concept("103-01-99")
      bibliography = described_class.build([concept])
      expect(bibliography.entries).to be_empty
    end

    it "serializes to YAML wrapping entries under 'bibliography'" do
      bibliography = described_class.build([concept_with_vim_source])
      yaml = YAML.safe_load(bibliography.to_yaml)

      expect(yaml).to have_key("bibliography")
      expect(yaml["bibliography"]).to be_an(Array)
      expect(yaml["bibliography"].first).to have_key("id")
    end

    it "preserves link from origin" do
      concepts = [concept_with_vim_source]
      bibliography = described_class.build(concepts)

      entry = bibliography.entries.first
      expect(entry.link).to eq("https://www.bipm.org")
    end
  end

  describe "id normalization" do
    it "normalizes id using same rules as Glossarist BibliographyIndex" do
      concept = build_concept("103-01-10") do |l10n|
        l10n.data.sources = [build_source(source: "IEC", id: "60050-103:2009")]
      end

      bibliography = described_class.build([concept])
      entry = bibliography.entries.first

      expect(entry.id).to eq("iec_60050-103:2009".gsub(/[ \/:]/, "_").downcase)
    end
  end
  def build_concept(id)
    mc = Glossarist::ManagedConcept.new(data: { "id" => id })
    l10n = Glossarist::LocalizedConcept.new
    l10n.data.id = id
    l10n.data.language_code = "eng"
    yield l10n if block_given?
    mc.add_l10n(l10n)
    mc
  end

  def build_source(source:, id:, clause: nil, link: nil)
    ref = Glossarist::Citation::Ref.new(source: source, id: id)
    kwargs = { ref: ref }
    if clause
      kwargs[:locality] = Glossarist::Locality.new(
        type: "clause",
        reference_from: clause,
      )
    end
    kwargs[:link] = link if link
    Glossarist::ConceptSource.new(
      type: "authoritative",
      origin: Glossarist::Citation.new(**kwargs),
    )
  end
end
