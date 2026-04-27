# frozen_string_literal: true

require "spec_helper"
require "yaml"

RSpec.describe "Iev" do
  let(:sample_xlsx) { fixture_path("sample-file.xlsx") }
  let(:sample_db) { fixture_path("sample-db.sqlite3") }

  describe "export" do
    let(:expected_concept1) do
      {
        "data" => {
          "identifier" => "103-01-01",
          "localized_concepts" => {
            "ara" => "2facc2da-b31c-5865-a461-7b09beb50306",
            "deu" => "b428bdb9-caae-56e2-843e-fc235e237caf",
            "eng" => "fb47471b-2692-5075-b273-b3f671e9ca9f",
            "fra" => "c390520c-2eab-540e-bf70-bfa68a5a5d71",
            "jpn" => "26880cae-c119-53f2-bd78-41c717173a69",
            "kor" => "9545c889-80f7-5662-8880-d8036a6c0378",
            "pol" => "3c3c4681-28c1-5df5-9c53-64f862750686",
            "por" => "3d56d72b-8c68-52f8-8965-ecfdef4d0ec8",
            "zho" => "a2ba7d83-7768-5460-a7df-7d3cd5246d84",
          },
        },
        "id" => "a9e98ffa-5960-5cd8-8f1e-9d0939da6fc0",
      }
    end

    let(:expected_localized_concept1) do
      {
        "data" => {
          "dates" => [
            {
              "date" => "2017-07-01T00:00:00+00:00",
              "type" => "accepted",
            },
            {
              "date" => "2017-07-01T00:00:00+00:00",
              "type" => "amended",
            },
          ],
          "definition" => [
            {
              "content" => "See {{IEV 102-01-10, IEV:102-01-10}}",
            },
          ],
          "examples" => [],
          "id" => "103-01-01",
          "notes" => [],
          "terms" => [
            {
              "type" => "expression",
              "normative_status" => "preferred",
              "designation" => "function",
            },
          ],
          "related" => [
            {
              "type" => "supersedes",
              "ref" => {
                "source" => "IEV",
                "id" => "103-01-01",
                "version" => "2009-12",
              },
            },
          ],
          "language_code" => "eng",
          "entry_status" => "valid",
          "review_date" => "2017-07-01T00:00:00+00:00",
          "review_decision_date" => "2017-07-01T00:00:00+00:00",
          "review_decision_event" => "published",
        },
        "date_accepted" => "2017-07-01T00:00:00+00:00",
        "id" => "fb47471b-2692-5075-b273-b3f671e9ca9f",
      }
    end

    it "exports YAMLs from a SQLite file" do
      Dir.mktmpdir("iev-test") do |dir|
        command = %W[export #{sample_db} -o #{dir}]
        Iev::Cli.start(command)

        concepts_dir = File.join(dir, "concepts")
        expect(concepts_dir).to(satisfy { |p| File.directory? p })
        expect(Dir["#{concepts_dir}/concept/*.yaml"]).not_to be_empty

        concept1 = YAML.load_file(File.join(concepts_dir, "concept",
                                            "a9e98ffa-5960-5cd8-8f1e-9d0939da6fc0.yaml"))
        localized = YAML.load_file(File.join(concepts_dir, "localized_concept",
                                             "#{concept1['data']['localized_concepts']['eng']}.yaml"))

        expect(concept1).to be_yaml_equivalent_to(expected_concept1)
        expect(localized).to be_yaml_equivalent_to(expected_localized_concept1)

        FileUtils.rm_rf(concepts_dir)
      end
    end

    it "exports YAMLs from an Excel file" do
      Dir.mktmpdir("iev-test") do |dir|
        command = %W[export #{sample_xlsx} -o #{dir}]
        silence_output_streams { Iev::Cli.start(command) }

        concepts_dir = File.join(dir, "concepts")
        expect(concepts_dir).to(satisfy { |p| File.directory? p })
        expect(Dir["#{concepts_dir}/concept/*.yaml"]).not_to be_empty

        concept1 = YAML.load_file(File.join(concepts_dir, "concept",
                                            "a9e98ffa-5960-5cd8-8f1e-9d0939da6fc0.yaml"))
        localized = YAML.load_file(File.join(concepts_dir, "localized_concept",
                                             "#{concept1['data']['localized_concepts']['eng']}.yaml"))

        expect(concept1).to be_yaml_equivalent_to(expected_concept1)
        expect(localized).to be_yaml_equivalent_to(expected_localized_concept1)

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
        expect(Dir[File.join(dir, "concepts", "concept", "*.yaml")]).not_to be_empty
      end
    end
  end
end
