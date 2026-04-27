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

    # #125: IEV links with 2-3 digit groups
    context "when IEV code has varying digit groups" do
      it "converts IEV link with 3-2-3 digit code" do
        text = 'See <a href="IEV702-07-781">IEV 702-07-781</a>'

        expect(subject.parse_anchor_tag(text, "IEV"))
          .to eq("See {{IEV 702-07-781, IEV:702-07-781}}")
      end

      it "converts IEV link with multiline content" do
        text = "See <a href=\"IEV702-07-781\">IEV\n702-07-781</a> for the noun"

        expect(subject.parse_anchor_tag(text, "IEV"))
          .to eq("See {{IEV\n702-07-781, IEV:702-07-781}} for the noun")
      end

      it "converts href without IEV prefix and 3-2-3 code" do
        text = '<a href="103-05-02">adjective</a>'

        expect(subject.parse_anchor_tag(text, "IEV"))
          .to eq("{{adjective, IEV:103-05-02}}")
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

    it "should replace <br/> tag with newlines" do
      expect(subject.replace_newlines("Hello<br/>world"))
        .to eq("Hello\n\nworld")
    end

    it "should replace <br /> tag with newlines" do
      expect(subject.replace_newlines("Hello<br />world"))
        .to eq("Hello\n\nworld")
    end
  end
end
