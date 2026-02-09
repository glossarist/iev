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
        "data" => {
          "identifier" => "103-01-01",
          "localized_concepts" => {
            "ara" => "bdb77f6b-5beb-53e9-ad15-ad2fa274b24a",
            "deu" => "e31b74fe-785f-5d91-aff5-d77b919485db",
            "eng" => "fb47471b-2692-5075-b273-b3f671e9ca9f",
            "fra" => "55272d39-f150-51ea-845f-d0a092964c14",
            "jpn" => "47740b93-6f57-5b37-97f3-69f41e65acbd",
            "kor" => "da5f0c48-2110-5d54-a274-7583189fb2d5",
            "pol" => "c85859a3-d630-50b6-9564-1bd4108472ee",
            "por" => "eaa113f3-247d-5b64-8b80-13eaecae5206",
            "zho" => "48ee39d6-4e9a-5fee-92b6-660496eb7f6b",
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

    let(:expected_concept2) do
      {
        "data" => {
          "identifier" => "103-01-02",
          "localized_concepts" => {
            "ara" => "60fe802b-844d-5e23-bd23-aa43e79cabed",
            "deu" => "a74756b7-aa12-5a3e-82b0-b37320cbf365",
            "eng" => "cac82820-d563-50d8-8166-73bc4bbc34ab",
            "fra" => "35052869-4db7-5ed1-959f-0cc4cbb87428",
            "jpn" => "2288f10b-bbeb-53b3-a58e-9968e338cc5b",
            "kor" => "a3b9a0e6-fdc4-520d-8caa-c50388bc91d4",
          },
        },
        "id" => "13ef6c25-6083-55e0-bcd8-85c887cafc6f",
      }
    end

    let(:expected_localized_concept2) do
      {
        "data" => {
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
        "id" => "a3b9a0e6-fdc4-520d-8caa-c50388bc91d4",
      }
    end

    it "exports YAMLs from given database" do
      Dir.mktmpdir("iev-test") do |dir|
        command = %W[db2yaml #{sample_db} -o #{dir}]
        # silence_output_streams { Iev::Cli.start(command) }
        Iev::Cli.start(command)

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

        expect(concept1).to be_yaml_equivalent_to(expected_concept1)
        expect(localized_concept1).to be_yaml_equivalent_to(expected_localized_concept1)

        expect(concept2).to be_yaml_equivalent_to(expected_concept2)
        expect(localized_concept2).to be_yaml_equivalent_to(expected_localized_concept2)

        FileUtils.rm_rf(concepts_dir)
      end
    end
  end
end
