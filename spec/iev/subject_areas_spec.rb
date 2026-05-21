# frozen_string_literal: true

require "spec_helper"

RSpec.describe Iev::SubjectAreas do
  before do
    described_class.instance_variable_set(:@typed_areas, nil)
    described_class.instance_variable_set(:@area_index, nil)
    described_class.instance_variable_set(:@section_index, nil)
    described_class.instance_variable_set(:@raw_data, nil)
  end

  after do
    described_class.instance_variable_set(:@typed_areas, nil)
    described_class.instance_variable_set(:@area_index, nil)
    described_class.instance_variable_set(:@section_index, nil)
    described_class.instance_variable_set(:@raw_data, nil)
  end

  describe ".all" do
    it "returns SubjectArea objects" do
      areas = described_class.all
      expect(areas).not_to be_empty
      expect(areas).to all(be_a(Iev::SubjectArea))
    end

    it "returns areas with string codes" do
      codes = described_class.all.map(&:code)
      expect(codes).to all(be_a(String))
      expect(codes).to include("102", "103")
    end
  end

  describe ".find_area" do
    it "finds an area by string code" do
      area = described_class.find_area("103")
      expect(area).to be_a(Iev::SubjectArea)
      expect(area.code).to eq("103")
    end

    it "finds an area by integer code" do
      area = described_class.find_area(103)
      expect(area).to be_a(Iev::SubjectArea)
      expect(area.code).to eq("103")
    end

    it "returns nil for unknown code" do
      expect(described_class.find_area("999")).to be_nil
    end
  end

  describe ".find_section" do
    it "finds a section by code" do
      section = described_class.find_section("103-01")
      expect(section).to be_a(Iev::Section)
      expect(section.code).to eq("103-01")
    end

    it "returns nil for unknown section" do
      expect(described_class.find_section("999-99")).to be_nil
    end
  end

  describe ".sections_for" do
    it "returns sections for an area code" do
      sections = described_class.sections_for("103")
      expect(sections).not_to be_empty
      expect(sections).to all(be_a(Iev::Section))
      expect(sections.map(&:area_code)).to all(eq("103"))
    end

    it "returns empty for unknown area" do
      expect(described_class.sections_for("999")).to eq([])
    end
  end

  describe ".area_for_section" do
    it "returns the parent area for a section code" do
      area = described_class.area_for_section("103-01")
      expect(area).to be_a(Iev::SubjectArea)
      expect(area.code).to eq("103")
    end

    it "returns nil for unknown section" do
      expect(described_class.area_for_section("999-99")).to be_nil
    end
  end

  describe ".area_for" do
    it "finds area from a full IEV reference" do
      area = described_class.area_for("103-01-02")
      expect(area).to be_a(Iev::SubjectArea)
      expect(area.code).to eq("103")
    end
  end

  describe ".section_for" do
    it "finds section from a full IEV reference" do
      section = described_class.section_for("103-01-02")
      expect(section).to be_a(Iev::Section)
      expect(section.code).to eq("103-01")
    end

    it "returns nil for area-only code" do
      expect(described_class.section_for("103")).to be_nil
    end
  end

  describe "URI scheme" do
    it "generates area URIs" do
      expect(described_class.area_uri("102")).to eq("area-102")
    end

    it "generates section URIs" do
      expect(described_class.section_uri("102-01")).to eq("section-102-01")
    end
  end

  describe ".reload!" do
    it "clears memoized caches" do
      described_class.all
      expect(described_class.instance_variable_get(:@typed_areas)).not_to be_nil

      described_class.reload!

      expect(described_class.instance_variable_get(:@typed_areas)).to be_nil
      expect(described_class.instance_variable_get(:@area_index)).to be_nil
      expect(described_class.instance_variable_get(:@section_index)).to be_nil
      expect(described_class.instance_variable_get(:@raw_data)).to be_nil
    end
  end
end
