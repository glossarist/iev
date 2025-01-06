# (c) Copyright 2020 Ribose Inc.
#

require "spec_helper"

RSpec.describe "string conversion refinements" do
  using Iev::DataConversions

  describe "#decode_html" do
    it "decodes HTML entities" do
      str = "&lt;b&gt;what a&lt;/b&gt; string &&amp; stuff"
      expect(str.decode_html).to eq("<b>what a</b> string && stuff")
    end

    it "returns decoded string but leaves self unchanged" do
      str = "&lt;&gt;"
      expect { str.decode_html }.not_to change { str }
      expect(str.decode_html).not_to eq(str)
    end
  end

  describe "#decode_html!" do
    it "decodes string in place" do
      str = "&lt;&gt;"
      expect { str.decode_html! }.to change { str }.to("<>")
    end
  end

  describe "#sanitize" do
    it "strips leading and trailing white spaces" do
      str = "  whatever\t"
      expect(str.sanitize).to eq("whatever")
    end

    it "removes uFEFF sequences" do
      str = "what\uFEFFever"
      expect(str.sanitize).to eq("whatever")
    end

    it "replaces u2011 (non-breaking dashes) with regular dashes" do
      str = "what\u2011ever"
      expect(str.sanitize).to eq("what-ever")
    end

    it "replaces u00a0 with regular spaces" do
      str = "what\u00a0ever"
      expect(str.sanitize).to eq("what ever")
    end

    it "returns sanitized string but leaves self unchanged" do
      str = "  what\uFEFFever\t"
      expect { str.sanitize }.not_to change { str }
      expect(str.sanitize).not_to eq(str)
    end
  end

  describe "#sanitize!" do
    it "sanitizes string in place" do
      str = "  whatever\t"
      expect { str.sanitize! }.to change { str }.to("whatever")
    end
  end

  describe "#to_three_char_code" do
    it "returns corresponding ISO 639-2 code for terminology" do
      expect("en".to_three_char_code).to eq("eng")
      expect("de".to_three_char_code).to eq("deu") # not ger
    end

    it "raises error when self is not a proper ISO 639-1 code" do
      expect { "whatever".to_three_char_code }.to raise_error(StandardError)
      expect { "xy".to_three_char_code }.to raise_error(StandardError)
      # already ISO 639-2
      expect { "eng".to_three_char_code }.to raise_error(StandardError)
    end
  end
end
