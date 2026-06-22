# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"

require "iev/fetcher"
require "iev/fetcher/cdx_index"

RSpec.describe Iev::Fetcher::CdxIndex do
  let(:cdx_json) do
    # Real CDX response shape: header row + data rows.
    JSON.dump([
                ["original", "timestamp"],
                [
                  "https://electropedia.org/iev/iev.nsf/display?openform&ievref=102-05-01", "20251001000000"
                ],
                [
                  "https://electropedia.org/iev/iev.nsf/display?openform&ievref=102-05-03", "20251002000000"
                ],
                [
                  "https://electropedia.org/iev/iev.nsf/display?openform&ievref=102-05-03", "20251101000000"
                ],
                [
                  "https://electropedia.org/iev/iev.nsf/display?openform&ievref=103-01-01", "20250915000000"
                ],
                [
                  "https://electropedia.org/iev/iev.nsf/display?openform&ievref=",          "20250901000000"
                ],
              ])
  end

  let(:tmp_path) do
    path = File.join(Dir.mktmpdir("iev-cdx"), "cdx.json")
    File.write(path, cdx_json, encoding: "utf-8")
    path
  end

  after { FileUtils.rm_rf(File.dirname(tmp_path)) }

  describe ".load" do
    it "builds an index keyed by section code" do
      index = described_class.load(tmp_path)

      expect(index.codes_for_section("102-05")).to eq(%w[102-05-01 102-05-03])
      expect(index.codes_for_section("103-01")).to eq(%w[103-01-01])
    end

    it "ignores URLs with no ievref code" do
      index = described_class.load(tmp_path)
      # The empty-ievref row should not contribute any section bucket.
      expect(index.sections).to eq(%w[102-05 103-01])
    end

    it "deduplicates within a section" do
      index = described_class.load(tmp_path)
      # 102-05-03 appears twice in the CDX data; bucket should have it once.
      expect(index.codes_for_section("102-05").count("102-05-03")).to eq(1)
    end
  end

  describe "#codes_for_section" do
    it "returns an empty array for an unknown section" do
      expect(described_class.load(tmp_path).codes_for_section("999-99")).to eq([])
    end

    it "returns a fresh array (caller can mutate without affecting index)" do
      index = described_class.load(tmp_path)
      list = index.codes_for_section("102-05")
      list << "102-05-99"
      expect(index.codes_for_section("102-05")).not_to include("102-05-99")
    end
  end

  describe "#total_codes" do
    it "counts unique codes across all sections" do
      expect(described_class.load(tmp_path).total_codes).to eq(3)
    end
  end

  describe "#sections" do
    it "returns sorted section codes" do
      expect(described_class.load(tmp_path).sections).to eq(%w[102-05 103-01])
    end
  end
end
