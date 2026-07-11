# frozen_string_literal: true

require "spec_helper"

RSpec.describe Iev::Reconciler::TermMarkerParser do
  describe ".parse" do
    it "extracts western feminine gender marker" do
      result = described_class.parse("Gleichheit, f")
      expect(result.designation).to eq("Gleichheit")
      expect(result.genders).to eq(["feminine"])
      expect(result.numbers).to be_empty
    end

    it "extracts western masculine gender marker" do
      result = described_class.parse("ensemble, m")
      expect(result.designation).to eq("ensemble")
      expect(result.genders).to eq(["masculine"])
    end

    it "extracts western neuter gender marker" do
      result = described_class.parse("Element, n")
      expect(result.designation).to eq("Element")
      expect(result.genders).to eq(["neuter"])
    end

    it "extracts Serbian gender + plurality markers" do
      result = described_class.parse("једнакост, ж јд")
      expect(result.designation).to eq("једнакост")
      expect(result.genders).to include("feminine")
      expect(result.numbers).to include("singular")
    end

    it "extracts Serbian masculine singular markers" do
      result = described_class.parse("скуп, м јд")
      expect(result.designation).to eq("скуп")
      expect(result.genders).to include("masculine")
      expect(result.numbers).to include("singular")
    end

    it "handles multiple western gender markers (f, n)" do
      result = described_class.parse("LED-Package, f, n")
      expect(result.designation).to eq("LED-Package")
      expect(result.genders).to contain_exactly("feminine", "neuter")
    end

    it "handles three gender markers (f, n, m)" do
      result = described_class.parse("LED-Package, f, n, m")
      expect(result.designation).to eq("LED-Package")
      expect(result.genders).to contain_exactly("feminine", "neuter", "masculine")
    end

    it "handles terms without markers" do
      result = described_class.parse("égalité")
      expect(result.designation).to eq("égalité")
      expect(result.genders).to be_empty
      expect(result.numbers).to be_empty
    end

    it "handles terms with stem math and gender marker" do
      result = described_class.parse("stem:[n]-dimensionaler Vektorraum, m")
      expect(result.designation).to eq("stem:[n]-dimensionaler Vektorraum")
      expect(result.genders).to eq(["masculine"])
    end

    it "handles nil input" do
      result = described_class.parse(nil)
      expect(result.designation).to be_nil
    end

    it "normalizes trailing whitespace before matching" do
      result = described_class.parse("Gleichheit, f\n")
      expect(result.designation).to eq("Gleichheit")
      expect(result.genders).to eq(["feminine"])
    end

    it "does not match regular comma in text" do
      result = described_class.parse("equality, defined as relation")
      expect(result.designation).to eq("equality, defined as relation")
      expect(result.genders).to be_empty
    end
  end

  describe ".parse_multiple" do
    it "splits multi-term cells by newlines" do
      results = described_class.parse_multiple("term one\nterm two")
      expect(results.size).to eq(2)
      expect(results[0].designation).to eq("term one")
      expect(results[1].designation).to eq("term two")
    end

    it "parses markers for each term independently" do
      results = described_class.parse_multiple("LED-Package, f\nLED-Modul, n")
      expect(results[0].designation).to eq("LED-Package")
      expect(results[0].genders).to eq(["feminine"])
      expect(results[1].designation).to eq("LED-Modul")
      expect(results[1].genders).to eq(["neuter"])
    end

    it "returns empty array for nil" do
      expect(described_class.parse_multiple(nil)).to eq([])
    end

    it "handles single term" do
      results = described_class.parse_multiple("equality")
      expect(results.size).to eq(1)
      expect(results[0].designation).to eq("equality")
    end
  end
end
