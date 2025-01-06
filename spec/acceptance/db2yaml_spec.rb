# frozen_string_literal: true

# (c) Copyright 2020 Ribose Inc.
#

require "spec_helper"
require "yaml"

RSpec.describe "Iev" do
  let(:sample_db) { fixture_path("sample-db.sqlite3") }

  describe "db2yaml" do
    let(:expected_concept1) do
      {
        "data" => { "identifier" => "103-01-01",
                    "localized_concepts" => { "ara" => "a36d1b2f-f3cd-5cf2-ade8-df02e5b87d0c",
                                              "deu" => "8ec20cf3-980d-59ba-87df-fabd0456516f", "eng" => "2257cbc6-142f-5c7b-aa0a-9aefb4eaad66", "fra" => "76f9d5e5-c7e7-5b44-b416-97ea4cab88ba", "jpn" => "33419587-0fe6-5bdb-8b56-64b844a7bdf8", "kor" => "6aaae1be-cfcb-56ad-b0d9-800665788576", "pol" => "35de3a28-5eb3-5aeb-98eb-68ebda314c05", "por" => "77fd4c13-8e92-5a7e-801d-1147829466ce", "zho" => "1cc72f48-8133-57ed-8361-4a24c1ec9d4a" } },
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
        "id" => "2257cbc6-142f-5c7b-aa0a-9aefb4eaad66",
        "status" => "valid",
      }
    end

    let(:expected_concept2) do
      {
        "data" => { "identifier" => "103-01-02",
                    "localized_concepts" => { "ara" => "b6fc2694-8d48-5cbf-9049-64604bbe72dd",
                                              "deu" => "b48bc0ef-422c-515f-81ec-3763d53d6e89", "eng" => "aeb511ce-9de0-5b98-a12d-5b920bd2dcd9", "fra" => "ba52518d-3e93-5b52-b18d-f2de54f620c8", "jpn" => "e08370c9-b29d-5984-8284-2051b1799d5a", "kor" => "f3593ebc-5afc-578a-942f-af346b59fba3" } },
        "id" => "13ef6c25-6083-55e0-bcd8-85c887cafc6f",
      }
    end

    let(:expected_localized_concept2) do
      {
        "data" => {
          "dates" => [],
          "definition" => [{}],
          "examples" => [],
          "id" => "103-01-02",
          "notes" => [],
          "terms" => [
            {
              "type" => "expression",
              "normative_status" => "preferred",
              "designation" => "범함수",
            },
          ],
          "language_code" => "kor",
          "entry_status" => "valid",
          "review_decision_event" => "published",
        },
        "id" => "f3593ebc-5afc-578a-942f-af346b59fba3",
        "status" => "valid",
      }
    end

    it "exports YAMLs from given database" do
      Dir.mktmpdir("iev-test") do |dir|
        command = %W[db2yaml #{sample_db} -o #{dir}]
        silence_output_streams { Iev::Cli.start(command) }

        concepts_dir = File.join(dir, "concepts")
        expect(concepts_dir).to(satisfy { |p| File.directory? p })
        expect(Dir["#{concepts_dir}/concept/*.yaml"]).not_to be_empty

        concept1 = YAML.load_file(File.join(concepts_dir, "concept",
                                            "a9e98ffa-5960-5cd8-8f1e-9d0939da6fc0.yaml"))
        localized_concept1 = YAML.load_file(File.join(concepts_dir, "localized_concept",
                                                      "#{concept1['data']['localized_concepts']['eng']}.yaml"))

        concept2 = YAML.load_file(File.join(concepts_dir, "concept",
                                            "13ef6c25-6083-55e0-bcd8-85c887cafc6f.yaml"))
        localized_concept2 = YAML.load_file(File.join(concepts_dir, "localized_concept",
                                                      "#{concept2['data']['localized_concepts']['kor']}.yaml"))

        expect(concept1).to eq(expected_concept1)
        expect(localized_concept1).to eq(expected_localized_concept1)

        expect(concept2).to eq(expected_concept2)
        expect(localized_concept2).to eq(expected_localized_concept2)

        FileUtils.rm_rf(concepts_dir)
      end
    end
  end
end
