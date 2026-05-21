# frozen_string_literal: true

require "spec_helper"

RSpec.describe Iev::IevCode do
  describe "full IEV code (3 parts)" do
    subject(:code) { described_class.new("103-01-02") }

    it "extracts area code" do
      expect(code.area_code).to eq("103")
    end

    it "extracts section code" do
      expect(code.section_code).to eq("103-01")
    end

    it "extracts concept number" do
      expect(code.number).to eq("02")
    end

    it "returns area URI" do
      expect(code.area_uri).to eq("area-103")
    end

    it "returns section URI" do
      expect(code.section_uri).to eq("section-103-01")
    end

    it "round-trips via to_s" do
      expect(code.to_s).to eq("103-01-02")
    end

    it "is coercible to String" do
      expect(code.to_str).to eq("103-01-02")
    end
  end

  describe "section code (2 parts)" do
    subject(:code) { described_class.new("103-01") }

    it "extracts area code" do
      expect(code.area_code).to eq("103")
    end

    it "extracts section code" do
      expect(code.section_code).to eq("103-01")
    end

    it "has no concept number" do
      expect(code.number).to be_nil
    end

    it "returns area URI" do
      expect(code.area_uri).to eq("area-103")
    end

    it "returns section URI" do
      expect(code.section_uri).to eq("section-103-01")
    end
  end

  describe "area code (1 part)" do
    subject(:code) { described_class.new("103") }

    it "extracts area code" do
      expect(code.area_code).to eq("103")
    end

    it "has no section code" do
      expect(code.section_code).to be_nil
    end

    it "has no concept number" do
      expect(code.number).to be_nil
    end

    it "returns area URI" do
      expect(code.area_uri).to eq("area-103")
    end

    it "returns nil section URI" do
      expect(code.section_uri).to be_nil
    end
  end

  describe "coercion from integer" do
    it "converts integer to string" do
      code = described_class.new(103)
      expect(code.area_code).to eq("103")
    end
  end

  describe ".parse" do
    it "returns IevCode for valid input" do
      code = described_class.parse("103-01-02")
      expect(code).to be_a(described_class)
      expect(code.area_code).to eq("103")
    end

    it "returns IevCode for partial input" do
      code = described_class.parse("103-01")
      expect(code).to be_a(described_class)
    end
  end

  describe "equality" do
    it "is equal when codes match" do
      a = described_class.new("103-01-02")
      b = described_class.new("103-01-02")
      expect(a).to eq(b)
      expect(a.hash).to eq(b.hash)
    end

    it "is not equal when codes differ" do
      a = described_class.new("103-01-02")
      b = described_class.new("103-01-03")
      expect(a).not_to eq(b)
    end
  end

  describe "comparison" do
    it "sorts by string value" do
      codes = [
        described_class.new("103-02-01"),
        described_class.new("103-01-02"),
        described_class.new("102-01-01"),
      ]
      expect(codes.sort.map(&:to_s)).to eq(%w[102-01-01 103-01-02 103-02-01])
    end
  end

  describe "immutability" do
    it "is frozen" do
      code = described_class.new("103-01-02")
      expect(code).to be_frozen
    end
  end
end
