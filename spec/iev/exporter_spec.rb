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
        expect(domain_ids).to include("section-103-01")

        domains.each do |d|
          expect(d.source).to eq("urn:iec:std:iec:60050")
          expect(d.ref_type).to eq("section")
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
        expect(domains.length).to eq(1)

        domain_ids = domains.map { |d| d["concept_id"] }
        expect(domain_ids).to include("section-103-01")

        domains.each do |d|
          expect(d["source"]).to eq("urn:iec:std:iec:60050")
          expect(d["ref_type"]).to eq("section")
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

  describe "tags" do
    it "assigns area and section titles as tags" do
      Dir.mktmpdir("iev-test") do |dir|
        collection = described_class.new(sample_db, output_dir: dir).export

        concept = collection.find { |c| c.data.id == "103-01-01" }
        expect(concept).not_to be_nil

        tags = concept.data.tags
        expect(tags).to include("Mathematics - Functions")
        expect(tags).to include("General concepts")
      end
    end

    it "serializes tags to YAML" do
      Dir.mktmpdir("iev-test") do |dir|
        described_class.new(sample_db, output_dir: dir).export

        concepts_dir = File.join(dir, "concepts")
        concept_files = Dir["#{concepts_dir}/*.yaml"]
        concept1 = concept_files.each do |f|
          docs = YAML.load_stream(File.read(f, encoding: "utf-8"))
          mc = docs.first
          break mc if mc.dig("data", "identifier") == "103-01-01"
        end

        tags = concept1["data"]["tags"]
        expect(tags).to include("Mathematics - Functions", "General concepts")
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
            "(concept has broader → #{broader_id})",
          )
        end
      end
    end
  end
  describe "register.yaml generation" do
    it "writes register.yaml with hierarchical sections" do
      Dir.mktmpdir("iev-test") do |dir|
        described_class.new(sample_db, output_dir: dir).export

        register_path = File.join(dir, "register.yaml")
        expect(File.exist?(register_path)).to be true

        register = YAML.safe_load(File.read(register_path, encoding: "utf-8"))
        expect(register["schema_type"]).to eq("glossarist")
        expect(register["id"]).to eq("iev")
        expect(register["urn"]).to eq("urn:iec:std:iec:60050")
        expect(register["ordering"]).to eq("systematic")

        sections = register["sections"]
        expect(sections).to be_an(Array)
        expect(sections.length).to be > 0

        # Find area 103
        area_103 = sections.find { |s| s["id"] == "103" }
        expect(area_103).not_to be_nil
        expect(area_103["names"]["eng"]).to eq("Mathematics - Functions")

        # Area 103 should have child sections
        children = area_103["children"]
        expect(children).to be_an(Array)
        expect(children.length).to be > 0

        section_103_01 = children.find { |s| s["id"] == "103-01" }
        expect(section_103_01).not_to be_nil
        expect(section_103_01["names"]["eng"]).to eq("General concepts")
      end
    end
  end

end
