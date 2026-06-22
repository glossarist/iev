# frozen_string_literal: true

require "spec_helper"
require "iev/fetcher"
require "iev/fetcher/scope"

RSpec.describe Iev::Fetcher::Scope do
  describe ".all" do
    it "includes every section from SubjectAreas" do
      scope = described_class.all
      expect(scope.sections).not_to be_empty
      expect(scope.sections).to all(be_a(Iev::Section))
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

    it "raises ArgumentError for an unknown section" do
      expect { described_class.for_section("999-99") }
        .to raise_error(ArgumentError, /Unknown section: 999-99/)
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
