# frozen_string_literal: true

require "spec_helper"
require "nokogiri"
require "iev/scraper"
require "iev/scraper/page_parser"

RSpec.describe Iev::Scraper::PageParser do
  let(:html_fixture) { File.read(File.expand_path("../../examples/103_01_02.html", __dir__), encoding: "utf-8") }
  let(:doc) { Nokogiri::HTML(html_fixture) }
  let(:parser) { described_class.new(doc, "103-01-02") }

  describe "#parse" do
    subject { parser.parse }

    it "returns a concept hash with id and data" do
      expect(subject).to be_a(Hash)
      expect(subject["id"]).to eq("103-01-02")
      expect(subject["data"]["identifier"]).to eq("103-01-02")
    end

    it "extracts localized concepts for all languages" do
      concepts = subject["data"]["localized_concepts"]
      expect(concepts).to be_a(Hash)
      expect(concepts.keys).to include("eng", "fra", "ara", "deu", "kor", "jpn")
    end

    it "extracts the English term" do
      eng = subject["data"]["localized_concepts"]["eng"]
      expect(eng["term"]).to eq("functional")
    end

    it "extracts the English definition" do
      eng = subject["data"]["localized_concepts"]["eng"]
      expect(eng["definition"]).to include("function for which the argument")
    end

    it "extracts the French term" do
      fra = subject["data"]["localized_concepts"]["fra"]
      expect(fra["term"]).to eq("fonctionnelle")
    end

    it "extracts the French definition" do
      fra = subject["data"]["localized_concepts"]["fra"]
      expect(fra["definition"]).to include("fonction dont l'argument")
    end

    it "extracts the Korean term" do
      kor = subject["data"]["localized_concepts"]["kor"]
      expect(kor["term"]).to eq("범함수")
    end

    it "extracts the Japanese term" do
      jpn = subject["data"]["localized_concepts"]["jpn"]
      expect(jpn["term"]).to eq("汎関数")
    end

    it "extracts the Arabic term" do
      ara = subject["data"]["localized_concepts"]["ara"]
      expect(ara["term"]).to eq("دالى")
    end

    it "extracts the German term" do
      deu = subject["data"]["localized_concepts"]["deu"]
      expect(deu["term"]).to eq("Funktional, n")
    end
  end

  context "with 111-11-11 fixture" do
    let(:html_fixture) { File.read(File.expand_path("../../examples/111_11_11.html", __dir__), encoding: "utf-8") }
    let(:parser) { described_class.new(doc, "111-11-11") }

    it "extracts the concept" do
      result = parser.parse
      expect(result["id"]).to eq("111-11-11")
      expect(result["data"]["localized_concepts"]).to be_a(Hash)
    end
  end
end
