# frozen_string_literal: true

require "spec_helper"
require "yaml"

RSpec.describe "Iev" do
  let(:sample_xlsx) { fixture_path("sample-file.xlsx") }
  let(:sample_db) { fixture_path("sample-db.sqlite3") }

  describe "export" do
    it "exports YAMLs from a SQLite file" do
      Dir.mktmpdir("iev-test") do |dir|
        command = %W[export #{sample_db} -o #{dir}]
        Iev::Cli.start(command)

        concepts_dir = File.join(dir, "concepts")
        expect(concepts_dir).to(satisfy { |p| File.directory? p })

        concept_files = Dir["#{concepts_dir}/*.yaml"]
        expect(concept_files).not_to be_empty

        concept1 = find_concept_by_identifier(concept_files, "103-01-01")
        expect(concept1["data"]["identifier"]).to eq("103-01-01")
        # domains[] includes both "domain" (area) and "section" refs
        expect(concept1["data"]["domains"]).to include(
          include("concept_id" => "area-103", "ref_type" => "domain"),
          include("concept_id" => "section-103-01", "ref_type" => "section"),
        )

        localized_eng = find_localized_in_grouped(concept_files, "103-01-01",
                                                  "eng")
        # ConceptData#domain is a localized string (section title), not a URI
        expect(localized_eng["data"]["domain"]).to eq("General concepts")
        expect(localized_eng["data"]["terms"].first["designation"]).to eq("function")
        expect(localized_eng["data"]["entry_status"]).to eq("valid")

        FileUtils.rm_rf(concepts_dir)
      end
    end

    it "exports YAMLs from an Excel file" do
      Dir.mktmpdir("iev-test") do |dir|
        command = %W[export #{sample_xlsx} -o #{dir}]
        silence_output_streams { Iev::Cli.start(command) }

        concepts_dir = File.join(dir, "concepts")
        expect(concepts_dir).to(satisfy { |p| File.directory? p })

        concept_files = Dir["#{concepts_dir}/*.yaml"]
        expect(concept_files).not_to be_empty

        concept1 = find_concept_by_identifier(concept_files, "103-01-01")
        expect(concept1["data"]["identifier"]).to eq("103-01-01")
        # domains[] includes both "domain" (area) and "section" refs
        expect(concept1["data"]["domains"]).to include(
          include("concept_id" => "area-103", "ref_type" => "domain"),
          include("concept_id" => "section-103-01", "ref_type" => "section"),
        )

        localized_eng = find_localized_in_grouped(concept_files, "103-01-01",
                                                  "eng")
        # ConceptData#domain is a localized string (section title), not a URI
        expect(localized_eng["data"]["domain"]).to eq("General concepts")
        expect(localized_eng["data"]["terms"].first["designation"]).to eq("function")

        FileUtils.rm_rf(concepts_dir)
      end
    end
  end

  describe "Iev::Exporter" do
    it "raises ArgumentError for unsupported file format" do
      Dir.mktmpdir("iev-test") do |dir|
        bad_file = File.join(dir, "data.csv")
        File.write(bad_file, "not ieved data")
        expect { Iev::Exporter.new(bad_file) }
          .to raise_error(ArgumentError, /Unsupported format/)
      end
    end

    it "raises ArgumentError for missing file" do
      expect { Iev::Exporter.new("nonexistent.xlsx") }
        .to raise_error(ArgumentError, /Input file not found/)
    end

    it "exports programmatically from a SQLite file" do
      Dir.mktmpdir("iev-test") do |dir|
        collection = Iev::Exporter.new(sample_db, output_dir: dir).export

        expect(collection).to be_a(Glossarist::ManagedConceptCollection)
        expect(Dir[File.join(dir, "concepts", "*.yaml")]).not_to be_empty
      end
    end
  end

  private

  def find_concept_by_identifier(concept_files, identifier)
    concept_files.each do |f|
      docs = YAML.load_stream(File.read(f, encoding: "utf-8"))
      mc = docs.first
      return mc if mc.dig("data", "identifier") == identifier
    end
    raise "Concept #{identifier} not found in #{concept_files.length} files"
  end

  def find_localized_in_grouped(concept_files, identifier, lang)
    concept_files.each do |f|
      docs = YAML.load_stream(File.read(f, encoding: "utf-8"))
      mc = docs.first
      next unless mc.dig("data", "identifier") == identifier

      lc = docs.find { |d| d.dig("data", "language_code") == lang }
      return lc if lc
    end
    raise "No #{lang} localization for #{identifier}"
  end
end
