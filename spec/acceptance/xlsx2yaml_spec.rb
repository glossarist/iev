# frozen_string_literal: true

# (c) Copyright 2020 Ribose Inc.
#

require "spec_helper"

RSpec.describe "Iev" do
  let(:sample_xlsx_file) { fixture_path("sample-file.xlsx") }

  describe "xlsx2yaml" do
    let(:expected_concept1) do
      {
        "data" => {
          "identifier" => "103-01-01",
          "localized_concepts" => {
            "ara" => "2facc2da-b31c-5865-a461-7b09beb50306",
            "deu" => "b428bdb9-caae-56e2-843e-fc235e237caf",
            "eng" => "fb47471b-2692-5075-b273-b3f671e9ca9f",
            "fra" => "c390520c-2eab-540e-bf70-bfa68a5a5d71",
            "jpn" => "c7120404-7fea-5433-aa45-a2f314935991",
            "kor" => "a89b8a05-ca41-5fb7-b435-c9bec070cd6f",
            "pol" => "18ab22c6-5924-520b-978d-9344491a38e9",
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

    let(:expected_concept2) do
      {
        "data" => {
          "identifier" => "103-01-02",
          "localized_concepts" => {
            "ara" => "6ede724c-74e6-59da-b4e6-ae13f7f9ab17",
            "deu" => "974775b1-ce18-5718-ad79-ec092c83df24",
            "eng" => "cac82820-d563-50d8-8166-73bc4bbc34ab",
            "fra" => "6ed485dc-3cbf-5b2f-ad9b-17009da3e2b5",
            "jpn" => "c86300c6-3b00-5c74-ae88-459d49e766a4",
            "kor" => "9e352209-a7b6-50b3-9906-b91d87015f9a",
          },
        },
        "id" => "13ef6c25-6083-55e0-bcd8-85c887cafc6f",
      }
    end

    let(:expected_localized_concept2) do
      {
        "data" => {
          "definition" => [],
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
        "id" => "9e352209-a7b6-50b3-9906-b91d87015f9a",
      }
    end

    it "exports YAMLs from given XLSX document" do
      Dir.mktmpdir("iev-test") do |dir|
        command = %W[xlsx2yaml #{sample_xlsx_file} -o #{dir}]
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

        expect(concept1).to be_yaml_equivalent_to(expected_concept1)
        expect(localized_concept1).to be_yaml_equivalent_to(expected_localized_concept1)

        expect(concept2).to be_yaml_equivalent_to(expected_concept2)
        expect(localized_concept2).to be_yaml_equivalent_to(expected_localized_concept2)

        FileUtils.rm_rf(concepts_dir)
      end
    end
  end
end
