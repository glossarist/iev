# frozen_string_literal: true

require "spec_helper"

RSpec.describe Iev::MultiDocYaml do
  def build_l10n(id, lang)
    l10n = Glossarist::LocalizedConcept.new
    l10n.data.id = id
    l10n.data.language_code = lang
    l10n
  end

  def build_concept(id, langs)
    mc = Glossarist::ManagedConcept.new(data: { "id" => id })
    mc.id = id
    langs.each { |lang| mc.add_l10n(build_l10n(id, lang)) }
    mc
  end

  def parse_stream(yaml)
    YAML.load_stream(yaml)
  end

  describe ".join" do
    it "keeps marker-less parts separate YAML documents" do
      parts = ["a: 1\n", "b: 2\n"]

      docs = parse_stream(described_class.join(parts))

      expect(docs.length).to eq(2)
      expect(docs.first).to eq("a" => 1)
      expect(docs.last).to eq("b" => 2)
    end

    it "keeps parts that already carry the document marker intact" do
      parts = ["---\na: 1\n", "---\nb: 2\n"]

      docs = parse_stream(described_class.join(parts))

      expect(docs.length).to eq(2)
      expect(docs).to contain_exactly({ "a" => 1 }, { "b" => 2 })
    end
  end

  describe ".parts_for" do
    it "serializes the concept first, then each localization" do
      concept = build_concept("103-01-01", %w[eng zho])

      parts = described_class.parts_for(concept)

      expect(parts.length).to eq(3)
      docs = parse_stream(described_class.join(parts))
      expect(docs.length).to eq(3)
      expect(docs.first.dig("data", "identifier")).to eq("103-01-01")
      expect(docs.first.dig("data", "localized_concepts").keys)
        .to contain_exactly("eng", "zho")
    end

    it "omits localizations that are absent" do
      concept = build_concept("103-01-01", [])

      parts = described_class.parts_for(concept)

      expect(parts.length).to eq(1)
    end
  end

  describe ".write" do
    it "writes a parseable document stream to path" do
      Dir.mktmpdir("iev-multi-doc") do |dir|
        path = File.join(dir, "concept.yaml")

        described_class.write(path, ["a: 1\n", "b: 2\n"])

        docs = parse_stream(File.read(path, encoding: "utf-8"))
        expect(docs.map(&:length)).to eq([1, 1])
      end
    end
  end

  describe ".save_grouped_concepts" do
    it "writes one marker-safe grouped file per managed concept" do
      Dir.mktmpdir("iev-multi-doc") do |dir|
        collection = Glossarist::ManagedConceptCollection.new
        collection.store(build_concept("103-01-01", %w[eng zho]))

        described_class.save_grouped_concepts(collection, dir)

        path = File.join(dir, "103-01-01.yaml")
        expect(File.exist?(path)).to be(true)
        docs = parse_stream(File.read(path, encoding: "utf-8"))
        expect(docs.length).to eq(3)
        expect(docs.first.dig("data", "identifier")).to eq("103-01-01")
        expect(docs.first.dig("data", "localized_concepts")["eng"])
          .to be_a(String)
      end
    end
  end
end
