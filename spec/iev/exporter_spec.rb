# frozen_string_literal: true

require "spec_helper"

RSpec.describe Iev::Exporter do
  describe "domain reference construction" do
    let(:sample_db) { fixture_path("sample-db.sqlite3") }

    it "assigns domain ConceptReferences to exported concepts" do
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
          expect(d.ref_type).to eq("domain")
        end
      end
    end

    it "serializes domains to YAML with ConceptReference structure" do
      Dir.mktmpdir("iev-test") do |dir|
        described_class.new(sample_db, output_dir: dir).export

        concepts_dir = File.join(dir, "concepts")
        concept_files = Dir["#{concepts_dir}/concept/*.yaml"]
        concept1 = concept_files.each do |f|
          data = YAML.load_file(f)
          break data if data.dig("data", "identifier") == "103-01-01"
        end

        domains = concept1["data"]["domains"]
        expect(domains).to be_an(Array)
        expect(domains.length).to eq(2)

        domain_ids = domains.map { |d| d["concept_id"] }
        expect(domain_ids).to include("area-103", "section-103-01")

        domains.each do |d|
          expect(d["ref_type"]).to eq("domain")
        end
      end
    end
  end
end
