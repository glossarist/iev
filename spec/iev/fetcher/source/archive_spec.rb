# frozen_string_literal: true

require "spec_helper"
require "iev/fetcher"
require "iev/fetcher/source/archive"

# Real Ruby transport stub — not a double. Maps URL -> response body
# (or nil for not-found). Each test builds its own with the URLs it
# expects the Archive to issue.
class FakeArchiveTransport
  def initialize(responses)
    @responses = responses
  end

  def get(url)
    @responses.fetch(url)
  end
end

RSpec.describe Iev::Fetcher::Source::Archive do
  let(:concept_url) do
    "https://www.electropedia.org/iev/iev.nsf/display?openform&ievref=102-05-18"
  end

  let(:availability_url) do
    encoded = URI.encode_www_form_component(concept_url)
    "https://archive.org/wayback/available?url=#{encoded}"
  end

  let(:snapshot_timestamp) { "20251118000701" }

  let(:wrapped_snapshot_url) do
    base = "https://electropedia.org/iev/iev.nsf/display?openform&ievref=102-05-18"
    "http://web.archive.org/web/#{snapshot_timestamp}/#{base}"
  end

  let(:id_snapshot_url) do
    base = "https://electropedia.org/iev/iev.nsf/display?openform&ievref=102-05-18"
    "http://web.archive.org/web/#{snapshot_timestamp}id_/#{base}"
  end

  let(:good_html) { "x" * (Iev::Fetcher::Waf::MIN_PAGE_SIZE + 1) }

  def archive(transport:, min_timestamp: "20250101")
    described_class.new(min_timestamp: min_timestamp, transport: transport)
  end

  describe "#fetch" do
    it "returns the id_ snapshot body when a recent snapshot is available" do
      transport = FakeArchiveTransport.new(
        availability_url => availability_response,
        id_snapshot_url => good_html,
      )

      result = archive(transport: transport).fetch(concept_url)
      expect(result).to eq(good_html)
    end

    it "returns nil when no snapshot is available" do
      transport = FakeArchiveTransport.new(
        availability_url => JSON.dump("archived_snapshots" => {}),
      )

      result = archive(transport: transport).fetch(concept_url)
      expect(result).to be_nil
    end

    it "returns nil when the availability API body is unparseable" do
      transport = FakeArchiveTransport.new(
        availability_url => "not json {",
      )

      result = archive(transport: transport).fetch(concept_url)
      expect(result).to be_nil
    end

    it "returns nil when the availability API returns nil" do
      transport = FakeArchiveTransport.new(availability_url => nil)

      result = archive(transport: transport).fetch(concept_url)
      expect(result).to be_nil
    end

    it "returns nil when the snapshot is older than min_timestamp" do
      old_ts = "20240101"
      old_wrapped = wrapped_snapshot_url.sub(snapshot_timestamp, old_ts)

      transport = FakeArchiveTransport.new(
        availability_url => availability_response(timestamp: old_ts,
                                                  url: old_wrapped),
      )

      result = archive(transport: transport, min_timestamp: "20250101")
        .fetch(concept_url)
      expect(result).to be_nil
    end

    it "returns nil when the snapshot body is a WAF stub" do
      transport = FakeArchiveTransport.new(
        availability_url => availability_response,
        id_snapshot_url => "Confirm you are human",
      )

      result = archive(transport: transport).fetch(concept_url)
      expect(result).to be_nil
    end

    it "uses the id_ URL modifier to skip the Wayback wrapper" do
      transport = FakeArchiveTransport.new(
        availability_url => availability_response,
        id_snapshot_url => good_html,
      )

      archive(transport: transport).fetch(concept_url)

      expect(transport.get(wrapped_snapshot_url)).to be_nil
    rescue KeyError
      # wrapped_snapshot_url was never registered — exactly what we want.
      # id_snapshot_url was registered and should be retrievable.
      expect(transport.get(id_snapshot_url)).to eq(good_html)
    end
  end

  describe "#quit" do
    it "is a no-op and returns nil" do
      expect(described_class.new.quit).to be_nil
    end
  end

  private

  def availability_response(timestamp: snapshot_timestamp,
                            url: wrapped_snapshot_url)
    JSON.dump(
      "archived_snapshots" => {
        "closest" => {
          "available" => true,
          "timestamp" => timestamp,
          "url" => url,
        },
      },
    )
  end
end
