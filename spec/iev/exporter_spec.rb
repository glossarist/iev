# frozen_string_literal: true

require "spec_helper"

RSpec.describe Iev::Exporter do
  let(:sample_db) { fixture_path("sample-db.sqlite3") }

  describe "domain reference construction" do
    it "assigns domain ConceptReferences with IEC URN source" do
      Dir.mktmpdir("iev-test") do |dir|
        collection = described_class.new(sample_db, output_dir: dir).export

        concept = collection.find { |c| c.data.id == "103-01-01" }
        expect(concept).not_to be_nil

        domains = concept.data.domains
        expect(domains).not_to be_empty
        expect(domains).to all(be_a(Glossarist::ConceptReference))

        domain_ids = domains.map(&:concept_id)
        expect(domain_ids).to include("area-103", "section-103-01")

        domains.each do |d|
          expect(d.source).to eq("urn:iec:std:iec:60050")
          expect(d.ref_type).to eq("domain")
        end
      end
    end

    it "serializes domains to YAML with source URN" do
      Dir.mktmpdir("iev-test") do |dir|
        described_class.new(sample_db, output_dir: dir).export

        concepts_dir = File.join(dir, "concepts")
        concept_files = Dir["#{concepts_dir}/*.yaml"]
        concept1 = concept_files.each do |f|
          docs = YAML.load_stream(File.read(f, encoding: "utf-8"))
          mc = docs.first
          break mc if mc.dig("data", "identifier") == "103-01-01"
        end

        domains = concept1["data"]["domains"]
        expect(domains).to be_an(Array)
        expect(domains.length).to eq(2)

        domain_ids = domains.map { |d| d["concept_id"] }
        expect(domain_ids).to include("area-103", "section-103-01")

        domains.each do |d|
          expect(d["source"]).to eq("urn:iec:std:iec:60050")
          expect(d["ref_type"]).to eq("domain")
        end
      end
    end
  end

  describe "broader relations on regular concepts" do
    it "adds broader relation pointing to section" do
      Dir.mktmpdir("iev-test") do |dir|
        collection = described_class.new(sample_db, output_dir: dir).export

        concept = collection.find { |c| c.data.id == "103-01-01" }
        expect(concept).not_to be_nil

        broader = concept.related&.select { |r| r.type == "broader" }
        expect(broader).not_to be_empty

        section_ref = broader.find { |r| r.content == "section-103-01" }
        expect(section_ref).not_to be_nil
        expect(section_ref.ref).to be_a(Glossarist::ConceptRef)
        expect(section_ref.ref.source).to eq("IEV")
        expect(section_ref.ref.id).to eq("section-103-01")
      end
    end
  end

  describe "narrower relations on section concepts" do
    it "adds narrower relations on sections pointing to child concepts" do
      Dir.mktmpdir("iev-test") do |dir|
        collection = described_class.new(sample_db, output_dir: dir).export

        section = collection.find { |c| c.data.id == "section-103-01" }
        expect(section).not_to be_nil

        narrower = section.related&.select { |r| r.type == "narrower" }
        expect(narrower).not_to be_empty

        narrower_ids = narrower.map(&:content)
        expect(narrower_ids).to include("103-01-01")
      end
    end

    it "sets ref on narrower relations for RDF transform" do
      Dir.mktmpdir("iev-test") do |dir|
        collection = described_class.new(sample_db, output_dir: dir).export

        section = collection.find { |c| c.data.id == "section-103-01" }
        narrower = section.related&.select { |r| r.type == "narrower" }

        narrower.each do |rel|
          expect(rel.ref).to be_a(Glossarist::ConceptRef)
          expect(rel.ref.source).to eq("IEV")
          expect(rel.ref.id).to eq(rel.content)
        end
      end
    end
  end

  describe "broader/narrower symmetry" do
    it "every concept broader has matching section narrower" do
      Dir.mktmpdir("iev-test") do |dir|
        collection = described_class.new(sample_db, output_dir: dir).export

        section = collection.find { |c| c.data.id == "section-103-01" }
        section_narrower_ids = section.related
          &.select { |r| r.type == "narrower" }
          &.map(&:content) || []

        concept = collection.find { |c| c.data.id == "103-01-01" }
        concept_broader_ids = concept.related
          &.select { |r| r.type == "broader" }
          &.map(&:content) || []

        concept_broader_ids.each do |broader_id|
          expect(section_narrower_ids).to(
            include("103-01-01"),
            "section-103-01 narrower should include 103-01-01 " \
            "(concept has broader → #{broader_id})"
          )
        end
      end
    end
  end
end
