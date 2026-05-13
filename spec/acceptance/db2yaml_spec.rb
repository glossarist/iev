# frozen_string_literal: true

# (c) Copyright 2020 Ribose Inc.
#

require "spec_helper"
require "yaml"

RSpec.describe "Iev" do
  let(:sample_db) { fixture_path("sample-db.sqlite3") }

  describe "db2yaml" do
    it "exports YAMLs from given database" do
      Dir.mktmpdir("iev-test") do |dir|
        command = %W[db2yaml #{sample_db} -o #{dir}]
        Iev::Cli.start(command)

        concepts_dir = File.join(dir, "concepts")
        expect(concepts_dir).to(satisfy { |p| File.directory? p })

        concept_files = Dir["#{concepts_dir}/concept/*.yaml"]
        expect(concept_files).not_to be_empty

        concept1 = find_concept_by_identifier(concept_files, "103-01-01")
        concept2 = find_concept_by_identifier(concept_files, "103-01-02")

        # Concept 1: basic structure
        expect(concept1["data"]["identifier"]).to eq("103-01-01")
        expect(concept1["data"]["localized_concepts"].keys).to contain_exactly(
          "ara", "deu", "eng", "fra", "jpn", "kor", "pol", "por", "zho",
        )
        expect(concept1["data"]["domains"]).to include(
          include("concept_id" => "area-103", "ref_type" => "domain"),
          include("concept_id" => "section-103-01", "ref_type" => "domain"),
        )

        localized_eng = load_localized(concepts_dir, concept1, "eng")
        expect(localized_eng["data"]["domain"]).to eq("section-103-01")
        expect(localized_eng["data"]["terms"].first["designation"]).to eq("function")
        expect(localized_eng["data"]["language_code"]).to eq("eng")
        expect(localized_eng["data"]["entry_status"]).to eq("valid")

        # Concept 2: basic structure
        expect(concept2["data"]["identifier"]).to eq("103-01-02")
        expect(concept2["data"]["domains"]).to include(
          include("concept_id" => "area-103", "ref_type" => "domain"),
          include("concept_id" => "section-103-01", "ref_type" => "domain"),
        )

        localized_kor = load_localized(concepts_dir, concept2, "kor")
        expect(localized_kor["data"]["domain"]).to eq("section-103-01")
        expect(localized_kor["data"]["terms"].first["designation"]).to eq("범함수")
        expect(localized_kor["data"]["language_code"]).to eq("kor")

        FileUtils.rm_rf(concepts_dir)
      end
    end
  end

  private

  def find_concept_by_identifier(concept_files, identifier)
    concept_files.each do |f|
      data = YAML.load_file(f)
      return data if data.dig("data", "identifier") == identifier
    end
    raise "Concept #{identifier} not found in #{concept_files.length} files"
  end

  def load_localized(concepts_dir, concept_data, lang)
    uuid = concept_data.dig("data", "localized_concepts", lang)
    raise "No #{lang} localization" unless uuid

    path = File.join(concepts_dir, "localized_concept", "#{uuid}.yaml")
    YAML.load_file(path)
  end
end
