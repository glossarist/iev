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
          .to eq("See {{121-02-02, urn:iec:std:iec:60050-121-02-02}}")
      end

      it "converts the a tag with quotes to asciidoc format" do
        text = "See <a href=IEV121-02-03>121-02-03</a>"

        expect(subject.parse_anchor_tag(text, "IEV"))
          .to eq("See {{121-02-03, urn:iec:std:iec:60050-121-02-03}}")
      end
    end

    context "when end tag is not present" do
      it "converts the a tag with quotes to asciidoc format" do
        text = 'See <a href="IEV121-02-02">No end tag'

        expect(subject.parse_anchor_tag(text, "IEV"))
          .to eq("See {{No end tag, urn:iec:std:iec:60050-121-02-02}}")
      end

      it "converts the a tag with quotes to asciidoc format" do
        text = "See <a href=IEV121-02-03>No end tag"

        expect(subject.parse_anchor_tag(text, "IEV"))
          .to eq("See {{No end tag, urn:iec:std:iec:60050-121-02-03}}")
      end
    end

    # #125: IEV links with 2-3 digit groups
    context "when IEV code has varying digit groups" do
      it "converts IEV link with 3-2-3 digit code" do
        text = 'See <a href="IEV702-07-781">IEV 702-07-781</a>'

        expect(subject.parse_anchor_tag(text, "IEV"))
          .to eq("See {{IEV 702-07-781, urn:iec:std:iec:60050-702-07-781}}")
      end

      it "converts IEV link with multiline content" do
        text = "See <a href=\"IEV702-07-781\">IEV\n702-07-781</a> for the noun"

        expect(subject.parse_anchor_tag(text, "IEV"))
          .to eq("See {{IEV\n702-07-781, urn:iec:std:iec:60050-702-07-781}} for the noun")
      end

      it "converts href without IEV prefix and 3-2-3 code" do
        text = '<a href="103-05-02">adjective</a>'

        expect(subject.parse_anchor_tag(text, "IEV"))
          .to eq("{{adjective, urn:iec:std:iec:60050-103-05-02}}")
      end
    end

    # CodeQL fix: unquoted href with space (IEV data: href=IEV 102-01-10)
    context "when href has unquoted value with space" do
      it "preserves the full IEV code including space" do
        text = "See <a href=IEV 102-01-10>IEV 102-01-10</a>"

        expect(subject.parse_anchor_tag(text, "103"))
          .to eq("See {{IEV 102-01-10, urn:iec:std:iec:60050-102-01-10}}")
      end
    end

    # Inline elements are converted directly in parse_anchor_tag
    context "when text contains italic and other inline elements" do
      it "converts <i> tags to stem notation" do
        text = "<i>f</i>(<i>t</i>)"

        expect(subject.parse_anchor_tag(text, "103"))
          .to eq("stem:[f](stem:[t])")
      end

      it "converts <sup> tags to caret notation" do
        text = "x<sup>2</sup>"

        expect(subject.parse_anchor_tag(text, "103"))
          .to eq("x^2^")
      end
    end

    # SIMG/Figure patterns (custom IEV XML, pre-processed with regex)
    # IEV format: SIMG tag followed by figure captions
    context "when text contains SIMG figure references" do
      it "converts SIMG with two figures" do
        text = '<simg type="negative"/$file/103-01-02en.gif>' \
               "<p><b> Figure  1  –  Description 1 </b></p>" \
               "<p><b> Figure  2  –  Description 2 </b></p>"

        result = subject.parse_anchor_tag(text, "103")
        expect(result).to start_with("image::/assets/images/parts/103/103-01-02en.gif[")
        expect(result).to include("Figure 1 - Description 1")
        expect(result).to include("Description 2")
      end

      it "converts SIMG with single figure" do
        text = '<simg type="negative"/$file/103-01-02en.gif>' \
               "<p><b> Figure  1  –  Description </b></p>"

        result = subject.parse_anchor_tag(text, "103")
        expect(result).to start_with("image::/assets/images/parts/103/103-01-02en.gif[")
        expect(result).to include("Figure 1 - Description")
      end

      it "converts standalone SIMG without figure label" do
        text = '<simg type="negative"/$file/103-01-02en.gif>'

        result = subject.parse_anchor_tag(text, "103")
        expect(result).to eq("image::/assets/images/parts/103/103-01-02en.gif[]")
      end
    end

    context "when text contains bold tags" do
      it "wraps bold content in asciidoc asterisks" do
        text = "<b>important</b>"

        expect(subject.parse_anchor_tag(text, "103"))
          .to eq("*important*")
      end
    end

    context "when text contains br tags" do
      it "converts br to newline" do
        text = "line1<br>line2"

        expect(subject.parse_anchor_tag(text, "103"))
          .to eq("line1\nline2")
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
