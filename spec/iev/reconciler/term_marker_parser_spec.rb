# frozen_string_literal: true

require "spec_helper"

RSpec.describe Iev::Reconciler::TermMarkerParser do
  describe ".parse" do
    it "extracts western feminine gender marker" do
      result = described_class.parse("Gleichheit, f")
      expect(result.designation).to eq("Gleichheit")
      expect(result.gender).to eq("f")
      expect(result.plurality).to be_nil
    end

    it "extracts western masculine gender marker" do
      result = described_class.parse("ensemble, m")
      expect(result.designation).to eq("ensemble")
      expect(result.gender).to eq("m")
    end

    it "extracts western neuter gender marker" do
      result = described_class.parse("Element, n")
      expect(result.designation).to eq("Element")
      expect(result.gender).to eq("n")
    end

    it "extracts Serbian gender + plurality markers" do
      result = described_class.parse("једнакост, ж јд")
      expect(result.designation).to eq("једнакост")
      expect(result.gender).to eq("ж")
      expect(result.plurality).to eq("јд")
    end

    it "extracts Serbian masculine singular markers" do
      result = described_class.parse("скуп, м јд")
      expect(result.designation).to eq("скуп")
      expect(result.gender).to eq("м")
      expect(result.plurality).to eq("јд")
    end

    it "handles terms without markers" do
      result = described_class.parse("égalité")
      expect(result.designation).to eq("égalité")
      expect(result.gender).to be_nil
      expect(result.plurality).to be_nil
    end

    it "handles terms with stem math and gender marker" do
      result = described_class.parse("stem:[n]-dimensionaler Vektorraum, m")
      expect(result.designation).to eq("stem:[n]-dimensionaler Vektorraum")
      expect(result.gender).to eq("m")
    end

    it "handles nil input" do
      result = described_class.parse(nil)
      expect(result.designation).to be_nil
    end

    it "does not match regular comma in text" do
      result = described_class.parse("equality, defined as relation")
      expect(result.designation).to eq("equality, defined as relation")
      expect(result.gender).to be_nil
    end
  end
end
