# frozen_string_literal: true

# (c) Copyright 2020 Ribose Inc.
#

require "spec_helper"

RSpec.describe "Iev" do
  let(:sample_xlsx_file) { fixture_path("sample-file.xlsx") }

  describe "xlsx2yaml" do
    it "exports YAMLs from given XLSX document" do
      Dir.mktmpdir("iev-test") do |dir|
        command = %W[xlsx2yaml #{sample_xlsx_file} -o #{dir}]
        silence_output_streams { Iev::Cli.start(command) }

        concepts_dir = File.join(dir, "concepts")
        expect(concepts_dir).to(satisfy { |p| File.directory? p })

        concept_files = Dir["#{concepts_dir}/*.yaml"]
        expect(concept_files).not_to be_empty

        concept1, docs1 = find_concept_by_identifier(concept_files, "103-01-01")
        concept2, docs2 = find_concept_by_identifier(concept_files, "103-01-02")

        # Concept 1 structure
        expect(concept1["data"]["identifier"]).to eq("103-01-01")
        expect(concept1["data"]["localized_concepts"].keys).to contain_exactly(
          "ara", "deu", "eng", "fra", "jpn", "kor", "pol", "por", "zho"
        )
        expect(concept1["data"]["domains"]).to include(
          include("concept_id" => "area-103", "ref_type" => "domain"),
          include("concept_id" => "section-103-01", "ref_type" => "domain"),
        )

        localized_eng = find_localized_in_docs(docs1, "eng")
        expect(localized_eng["data"]["domain"]).to eq("section-103-01")
        expect(localized_eng["data"]["terms"].first["designation"]).to eq("function")
        expect(localized_eng["data"]["entry_status"]).to eq("valid")

        # Concept 2 structure
        expect(concept2["data"]["identifier"]).to eq("103-01-02")
        expect(concept2["data"]["domains"]).to include(
          include("concept_id" => "area-103", "ref_type" => "domain"),
          include("concept_id" => "section-103-01", "ref_type" => "domain"),
        )

        localized_kor = find_localized_in_docs(docs2, "kor")
        expect(localized_kor["data"]["domain"]).to eq("section-103-01")
        expect(localized_kor["data"]["terms"].first["designation"]).to eq("범함수")

        FileUtils.rm_rf(concepts_dir)
      end
    end
  end

  private

  def find_concept_by_identifier(concept_files, identifier)
    concept_files.each do |f|
      docs = YAML.load_stream(File.read(f, encoding: "utf-8"))
      mc = docs.first
      return [mc, docs] if mc.dig("data", "identifier") == identifier
    end
    raise "Concept #{identifier} not found in #{concept_files.length} files"
  end

  def find_localized_in_docs(docs, lang)
    docs.find { |d| d.dig("data", "language_code") == lang }
  end
end
