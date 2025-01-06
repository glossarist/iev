# frozen_string_literal: true

require "spec_helper"

class TestUtilites
  include Iev::Utilities
end

RSpec.describe Iev::Utilities do
  subject { TestUtilites.new }

  describe "#parse_anchor_tag" do
    context "when end tag is present" do
      it "converts the a tag with quotes to asciidoc format" do
        text = 'See <a href="IEV121-02-02">121-02-02</a>'

        expect(subject.parse_anchor_tag(text, "IEV"))
          .to eq("See {{121-02-02, IEV:121-02-02}}")
      end

      it "converts the a tag with quotes to asciidoc format" do
        text = "See <a href=IEV121-02-03>121-02-03</a>"

        expect(subject.parse_anchor_tag(text, "IEV"))
          .to eq("See {{121-02-03, IEV:121-02-03}}")
      end
    end

    context "when end tag is not present" do
      it "converts the a tag with quotes to asciidoc format" do
        text = 'See <a href="IEV121-02-02">No end tag'

        expect(subject.parse_anchor_tag(text, "IEV"))
          .to eq("See {{No end tag, IEV:121-02-02}}")
      end

      it "converts the a tag with quotes to asciidoc format" do
        text = "See <a href=IEV121-02-03>No end tag"

        expect(subject.parse_anchor_tag(text, "IEV"))
          .to eq("See {{No end tag, IEV:121-02-03}}")
      end
    end
  end

  describe "#replace_newlines" do
    it "should replace <br> tag with newlines" do
      expect(subject.replace_newlines("Hello<br>world"))
        .to eq("Hello\n\nworld")
    end

    it "should replace <p> tag with newlines" do
      expect(subject.replace_newlines("Hello<p>world"))
        .to eq("Hello\n\nworld")
    end

    it 'should replace \\n tag with newlines' do
      expect(subject.replace_newlines('Hello\\nworld'))
        .to eq("Hello\n\nworld")
    end

    it 'should replace multiple \\n tag with newlines' do
      expect(subject.replace_newlines('Hello\\n\\n\\n\\n\\n\\nworld'))
        .to eq("Hello\n\nworld")
    end
  end
end
