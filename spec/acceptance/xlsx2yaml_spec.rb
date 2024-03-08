# (c) Copyright 2020 Ribose Inc.
#

require "spec_helper"

RSpec.describe "IEV" do
  let(:sample_xlsx_file) { fixture_path("sample-file.xlsx") }

  describe "xlsx2yaml" do
    let(:expected_concept1) do
      {
        "data" => {
          "identifier" => "103-01-01",
          "localized_concepts" => {
            "ara" => "0144dead-8444-5d99-947b-4b9433bdcbb2",
            "deu" => "64541958-58d4-5e9d-95bf-643cc0fb3e9c",
            "eng" => "2de73b1c-05e7-56c1-bdf2-d13cd06f7a96",
            "fra" => "517f9c27-2b32-555b-813b-ee271fc1e293",
            "jpn" => "4fa3997e-5c0d-5ec3-996b-6df06ba53446",
            "kor" => "66ef2513-c970-57e9-9429-21bc8e8a2d69",
            "pol" => "c37a8546-4175-51f8-b051-9dd8ef3fc2f7",
            "por" => "8e3daaee-b1c6-53ec-81d1-e70f0b4e24bb",
            "zho" => "f1981caa-f191-52a4-a012-be6883f17508",
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
            "fra" => "0ad9df6f-77a1-576f-9b46-2d0322bab4c7",
            "jpn" => "c3d3dc36-68cf-5ba3-8483-3d94ebb7d26a",
            "kor" => "88c5626d-0cd9-5616-8d04-e1a379eddda6",
          },
        },
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
      }
    end

    it "exports YAMLs from given XLSX document" do
      Dir.mktmpdir("iev-test") do |dir|
        command = %W(xlsx2yaml #{sample_xlsx_file} -o #{dir})
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

        FileUtils.rm_rf(concepts_dir)
      end
    end
  end
end
