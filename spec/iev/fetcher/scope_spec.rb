# frozen_string_literal: true

require "spec_helper"
require "iev/fetcher"
require "iev/fetcher/scope"
require "iev/fetcher/cdx_index"

# Minimal stand-in for CdxIndex — real Ruby class, not a double.
FakeCdx = Struct.new(:section_codes) do
  def sections = section_codes
end

RSpec.describe Iev::Fetcher::Scope do
  describe ".all" do
    it "includes every section from SubjectAreas" do
      scope = described_class.all
      expect(scope.sections).not_to be_empty
      expect(scope.sections).to all(be_a(Iev::Section))
    end
  end

  describe ".from_cdx" do
    it "builds a section per CDX section code" do
      cdx = FakeCdx.new(["102-01", "102-05", "103-01"])
      scope = described_class.from_cdx(cdx)

      expect(scope.sections.map(&:code)).to contain_exactly("102-01",
                                                            "102-05",
                                                            "103-01")
    end

    it "derives area_code from the section code" do
      cdx = FakeCdx.new(["102-05"])
      scope = described_class.from_cdx(cdx)

      expect(scope.sections.first.area_code).to eq("102")
    end

    it "synthesizes sections CDX has but yaml does not" do
      real_cdx = Iev::Fetcher::CdxIndex.load("tmp/cdx_display.json")
      scope = described_class.from_cdx(real_cdx)
      yaml_scope = described_class.all

      cdx_only = scope.sections.map(&:code) - yaml_scope.sections.map(&:code)
      expect(cdx_only).not_to be_empty
    end
  end

  describe ".for_area" do
    it "returns sections belonging to the given area" do
      scope = described_class.for_area("103")
      expect(scope.sections).not_to be_empty
      expect(scope.sections.map(&:area_code)).to all(eq("103"))
    end

    it "returns an empty scope for an unknown area" do
      scope = described_class.for_area("999")
      expect(scope.sections).to be_empty
    end
  end

  describe ".for_section" do
    it "returns a single-section scope" do
      scope = described_class.for_section("103-01")
      expect(scope.sections.map(&:code)).to eq(["103-01"])
    end

    it "synthesizes a Section record for CDX-only codes not in yaml" do
      scope = described_class.for_section("999-99")
      expect(scope.sections.map(&:code)).to eq(["999-99"])
      expect(scope.sections.first.area_code).to eq("999")
    end
  end

  describe "#includes?" do
    it "is true for a concept whose section is in scope" do
      scope = described_class.for_section("103-01")
      expect(scope.includes?("103-01-02")).to be(true)
    end

    it "is false for a concept whose section is not in scope" do
      scope = described_class.for_section("103-01")
      expect(scope.includes?("102-01-01")).to be(false)
    end

    it "is false for a code without a section part" do
      scope = described_class.for_section("103-01")
      expect(scope.includes?("103")).to be(false)
    end
  end

  describe "#each_section" do
    it "yields each section in the scope" do
      scope = described_class.for_area("103")
      yielded = []
      scope.each_section { |s| yielded << s.code }
      expect(yielded).to include("103-01")
    end
  end

  describe "#size" do
    it "returns the section count" do
      expect(described_class.for_section("103-01").size).to eq(1)
    end
  end
end
