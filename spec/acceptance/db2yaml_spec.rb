# (c) Copyright 2020 Ribose Inc.
#

require "spec_helper"
require "yaml"

RSpec.describe "IEV" do
  let(:sample_db) { fixture_path("sample-db.sqlite3") }

  describe "db2yaml" do
    let(:expected_concept1) do
      {
        "data" => {
          "identifier" => "103-01-01",
          "localized_concepts" => {
            "ara" => "0144dead-8444-5d99-947b-4b9433bdcbb2",
            "deu" => "e6d25854-cc79-5b08-8b57-af532d748429",
            "eng" => "2de73b1c-05e7-56c1-bdf2-d13cd06f7a96",
            "fra" => "072db199-e9a6-5d46-b733-6665aef5c621",
            "jpn" => "961a5a96-1eb9-5752-b00d-2712ed1212d4",
            "kor" => "25cf1117-3a19-5af2-99ef-0a8d0b31a02c",
            "pol" => "725a5c0e-2ff9-547d-a13e-74e22c507357",
            "por" => "c12e8aee-ad0c-5934-96fd-cea825844803",
            "zho" => "ef77689c-66bc-58d2-8189-c0953f7ad430",
          },
        },
      }
    end

    let(:expected_localized_concept1) do
      {
        "data" => {
          "dates" => [
            {
              "date" => "2017-07-01T00:00:00+00:00",
              "type" => "accepted"
            },
            {
              "date" => "2017-07-01T00:00:00+00:00",
              "type" => "amended"
            },
          ],
          "definition" => [
            {
              "content" => "See {{IEV 102-01-10, IEV:102-01-10}}"
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
            }
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
      }
    end

    let(:expected_concept2) do
      {
        "data" => {
          "identifier" => "103-01-02",
          "localized_concepts" =>
          {
            "ara" => "ab3f3785-fbed-5173-b6af-ca6eb0dcb3e1",
            "deu" => "d9c63649-bec9-554f-b012-06e174acecdb",
            "eng" => "ce70adb6-2252-5016-a843-2a42ce3327c7",
            "fra" => "35951b6a-e6db-5529-af7b-7d384ff52f9a",
            "jpn" => "c3d3dc36-68cf-5ba3-8483-3d94ebb7d26a",
            "kor" => "8e78b4af-d426-5220-8261-1b2dd3d7fb23",
          },
        },
      }
    end

    let(:expected_localized_concept2) do
      {
        "data" => {
          "dates" => [
            { "type" => "accepted" },
            { "type" => "amended" },
          ],
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
      }
    end

    it "exports YAMLs from given database" do
      Dir.mktmpdir("iev-test") do |dir|
        command = %W(db2yaml #{sample_db} -o #{dir})
        silence_output_streams { IEV::CLI.start(command) }

        concepts_dir = File.join(dir, "concepts")
        expect(concepts_dir).to satisfy { |p| File.directory? p }
        expect(Dir["#{concepts_dir}/concept/*.yaml"]).not_to be_empty

        concept1 = YAML.load_file(File.join(concepts_dir, "concept", "a9e98ffa-5960-5cd8-8f1e-9d0939da6fc0.yaml"))
        localized_concept1 = YAML.load_file(File.join(concepts_dir, "localized_concept", "#{concept1["data"]["localized_concepts"]["eng"]}.yaml"))

        concept2 = YAML.load_file(File.join(concepts_dir, "concept", "13ef6c25-6083-55e0-bcd8-85c887cafc6f.yaml"))
        localized_concept2 = YAML.load_file(File.join(concepts_dir, "localized_concept", "#{concept2["data"]["localized_concepts"]["kor"]}.yaml"))

        expect(concept1).to eq(expected_concept1)
        expect(localized_concept1).to eq(expected_localized_concept1)

        expect(concept2).to eq(expected_concept2)
        expect(localized_concept2).to eq(expected_localized_concept2)
      end
    end
  end
end
