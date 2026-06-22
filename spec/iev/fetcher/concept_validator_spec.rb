# frozen_string_literal: true

require "spec_helper"
require "iev/fetcher"
require "iev/fetcher/concept_validator"

RSpec.describe Iev::Fetcher::ConceptValidator do
  let(:real_html) do
    File.read(File.expand_path("../../examples/103_01_01_real.html", __dir__),
              encoding: "utf-8")
  end

  let(:placeholder_html) do
    File.read(File.expand_path("../../examples/103_01_99_placeholder.html",
                               __dir__), encoding: "utf-8")
  end

  it "accepts a real concept page with populated localized_concepts" do
    expect(described_class.new.valid?(real_html, "103-01-01")).to be(true)
  end

  it "rejects a placeholder page whose localized_concepts is empty" do
    expect(described_class.new.valid?(placeholder_html,
                                      "103-01-99")).to be(false)
  end

  it "rejects nil html" do
    expect(described_class.new.valid?(nil, "103-01-01")).to be(false)
  end

  it "rejects a short WAF challenge page" do
    expect(described_class.new.valid?("Confirm you are human", "103-01-01"))
      .to be(false)
  end
end
