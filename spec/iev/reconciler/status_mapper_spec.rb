# frozen_string_literal: true

require "spec_helper"

RSpec.describe Iev::Reconciler::StatusMapper do
  describe ".call" do
    it "maps Standard to valid" do
      expect(described_class.call("Standard")).to eq("valid")
    end

    it "maps Published to valid" do
      expect(described_class.call("Published")).to eq("valid")
    end

    it "maps Draft to draft" do
      expect(described_class.call("Draft")).to eq("draft")
    end

    it "maps Superseded to superseded" do
      expect(described_class.call("Superseded")).to eq("superseded")
    end

    it "maps Retired to retired" do
      expect(described_class.call("Retired")).to eq("retired")
    end

    it "defaults unknown to valid" do
      expect(described_class.call("Unknown")).to eq("valid")
    end

    it "handles nil" do
      expect(described_class.call(nil)).to eq("valid")
    end
  end
end
