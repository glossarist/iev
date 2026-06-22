# frozen_string_literal: true

require "spec_helper"
require "iev/fetcher"
require "iev/fetcher/waf"

RSpec.describe Iev::Fetcher::Waf do
  describe ".challenge?" do
    it "returns true for pages below MIN_PAGE_SIZE" do
      expect(described_class.challenge?("<html>short</html>")).to be(true)
    end

    it "returns false for nil html (nil is a soft failure, not a challenge)" do
      expect(described_class.challenge?(nil)).to be(false)
    end

    it "returns true when 'Confirm you are human' is present" do
      html = "#{'x' * described_class::MIN_PAGE_SIZE}Confirm you are human"
      expect(described_class.challenge?(html)).to be(true)
    end

    it "returns true when 'solve a puzzle' is present" do
      html = "#{'x' * described_class::MIN_PAGE_SIZE}solve a puzzle"
      expect(described_class.challenge?(html)).to be(true)
    end

    it "returns true when 'security check before continuing' is present" do
      marker = "security check before continuing"
      html = "#{'x' * described_class::MIN_PAGE_SIZE}#{marker}"
      expect(described_class.challenge?(html)).to be(true)
    end

    it "returns false for a normal large page without challenge markers" do
      html = "x" * (described_class::MIN_PAGE_SIZE + 1)
      expect(described_class.challenge?(html)).to be(false)
    end
  end

  describe ".fetch_with_retry" do
    it "returns the block result on first success" do
      result = described_class.fetch_with_retry { "<html>ok</html>" * 1000 }
      expect(result).to include("ok")
    end

    it "returns nil when the block returns nil without raising" do
      expect(described_class.fetch_with_retry { nil }).to be_nil
    end

    it "retries on a challenge then succeeds" do
      attempts = 0
      described_class.fetch_with_retry(retries: 3, delay: 0) do
        attempts += 1
        attempts < 2 ? "short" : ("x" * (described_class::MIN_PAGE_SIZE + 1))
      end
      expect(attempts).to eq(2)
    end

    it "raises Error after retries are exhausted" do
      attempts = 0
      expect do
        described_class.fetch_with_retry(retries: 2, delay: 0) do
          attempts += 1
          "short"
        end
      end.to raise_error(Iev::Fetcher::Waf::Error)

      expect(attempts).to eq(2)
    end

    it "uses linear backoff delay" do
      sleep_calls = []
      allow(described_class).to receive(:sleep) { |s| sleep_calls << s }

      begin
        described_class.fetch_with_retry(retries: 3, delay: 10) do
          "short"
        end
      rescue StandardError
        Iev::Fetcher::Waf::Error
      end

      expect(sleep_calls).to eq([10, 20])
    end
  end
end
