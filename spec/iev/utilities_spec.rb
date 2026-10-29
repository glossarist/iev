# frozen_string_literal: true

require "spec_helper"

class TestUtilites
  include Iev::Utilities
end

RSpec.describe Iev::Utilities do
  subject { TestUtilites.new }

  let(:fixture_dir) do
    File.expand_path("../fixtures/iev_html_partials", __dir__)
  end

  describe "#parse_anchor_tag" do
    context "when end tag is present" do
      it "converts the a tag with quotes to asciidoc format" do
        text = 'See <a href="IEV121-02-02">121-02-02</a>'

        expect(subject.parse_anchor_tag(text, "IEV"))
          .to eq("See {{urn:iec:std:iec:60050-121-02-02, 121-02-02}}")
      end

      it "converts the a tag with quotes to asciidoc format" do
        text = "See <a href=IEV121-02-03>121-02-03</a>"

        expect(subject.parse_anchor_tag(text, "IEV"))
          .to eq("See {{urn:iec:std:iec:60050-121-02-03, 121-02-03}}")
      end
    end

    context "when end tag is not present" do
      it "converts the a tag with quotes to asciidoc format" do
        text = 'See <a href="IEV121-02-02">No end tag'

        expect(subject.parse_anchor_tag(text, "IEV"))
          .to eq("See {{urn:iec:std:iec:60050-121-02-02, No end tag}}")
      end

      it "converts the a tag with quotes to asciidoc format" do
        text = "See <a href=IEV121-02-03>No end tag"

        expect(subject.parse_anchor_tag(text, "IEV"))
          .to eq("See {{urn:iec:std:iec:60050-121-02-03, No end tag}}")
      end
    end

    # #125: IEV links with 2-3 digit groups
    context "when IEV code has varying digit groups" do
      it "converts IEV link with 3-2-3 digit code" do
        text = 'See <a href="IEV702-07-781">IEV 702-07-781</a>'

        expect(subject.parse_anchor_tag(text, "IEV"))
          .to eq("See {{urn:iec:std:iec:60050-702-07-781, IEV 702-07-781}}")
      end

      it "converts IEV link with multiline content" do
        text = "See <a href=\"IEV702-07-781\">IEV\n702-07-781</a> for the noun"

        expect(subject.parse_anchor_tag(text, "IEV"))
          .to eq("See {{urn:iec:std:iec:60050-702-07-781, " \
                 "IEV\n702-07-781}} for the noun")
      end

      it "converts href without IEV prefix and 3-2-3 code" do
        text = '<a href="103-05-02">adjective</a>'

        expect(subject.parse_anchor_tag(text, "IEV"))
          .to eq("{{urn:iec:std:iec:60050-103-05-02, adjective}}")
      end
    end

    # CodeQL fix: unquoted href with space (IEV data: href=IEV 102-01-10)
    context "when href has unquoted value with space" do
      it "preserves the full IEV code including space" do
        text = "See <a href=IEV 102-01-10>IEV 102-01-10</a>"

        expect(subject.parse_anchor_tag(text, "103"))
          .to eq("See {{urn:iec:std:iec:60050-102-01-10, IEV 102-01-10}}")
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
        expect(result).to start_with(
          "image::/assets/images/parts/103/103-01-02en.gif[",
        )
        expect(result).to include("Figure 1 - Description 1")
        expect(result).to include("Description 2")
      end

      it "converts SIMG with single figure" do
        text = '<simg type="negative"/$file/103-01-02en.gif>' \
               "<p><b> Figure  1  –  Description </b></p>"

        result = subject.parse_anchor_tag(text, "103")
        expect(result).to start_with(
          "image::/assets/images/parts/103/103-01-02en.gif[",
        )
        expect(result).to include("Figure 1 - Description")
      end

      it "converts standalone SIMG without figure label" do
        text = '<simg type="negative"/$file/103-01-02en.gif>'

        result = subject.parse_anchor_tag(text, "103")
        expect(result).to eq(
          "image::/assets/images/parts/103/103-01-02en.gif[]",
        )
      end
    end

    # glossarist/iev-data#120: spans are unwrapped, including in table cells
    context "when text contains span elements" do
      it "unwraps a plain span" do
        text = "<span>concentration en quantité</span>stem:[c]~B~"

        expect(subject.parse_anchor_tag(text, "112"))
          .to eq("concentration en quantitéstem:[c]~B~")
      end

      it "unwraps spans inside table cells and keeps the table markup" do
        text = "<table><tr><td colspan=\"2\">\r\n<span>ohm</span>\r\n</td>" \
               "\r\n" \
               "<td style=\"width: 115px;\"><span>Ω</span></td></tr></table>"

        result = subject.parse_anchor_tag(text, "112")
        expect(result).not_to include("<span")
        expect(result).not_to include("\r")
        cells = Nokogiri::HTML.fragment(result).css("td")
        expect(cells.map { |c| c.text.strip }).to eq(["ohm", "Ω"])
        expect(cells.map { |c| c["colspan"] }).to eq(["2", nil])
      end
    end

    # glossarist/iev-data#120: exact cell fragments from the issue
    context "when text is a standalone table cell with spans" do
      it "unwraps spans in unit cells" do
        text = "<td style=\"width: 204px;\">\n\n<span>ohm</span>\r\n</td>" \
               "\r\n<td style=\"width: 115.033px;\">\n\n<span>Ω</span>" \
               "\r\n</td>"

        result = subject.parse_anchor_tag(text, "112")
        expect(result).not_to include("<span")
        expect(result).to eq(
          "<td style=\"width: 204px;\">\n\nohm\n</td>\n" \
          "<td style=\"width: 115.033px;\">\n\nΩ\n</td>",
        )
      end

      it "unwraps a span that holds a term followed by a formula" do
        text = "<td colspan=\"2\">\n\n<span>concentration en quantité de " \
               "matière du constituant B,\n</span>stem:[c]~B~\r\n</td>"

        expect(subject.parse_anchor_tag(text, "112")).to eq(
          "<td colspan=\"2\">\n\nconcentration en quantité de matière " \
          "du constituant B,\nstem:[c]~B~\n</td>",
        )
      end
    end

    # glossarist/iev-data#118
    context "when text contains SIMG elements without an image file" do
      it "drops a bare empty simg" do
        expect(subject.parse_anchor_tag("before <simg></simg>after", "102"))
          .to eq("before after")
      end

      it "keeps only the caption of a caption-only simg" do
        caption = "Figure 11 – Réponses typiques d'un système de commande à " \
                  "un échelon de la variable de référence (haut) et à un " \
                  "échelon de la variable perturbatrice (bas)]"

        expect(subject.parse_anchor_tag("<simg>\n#{caption}</simg>", "351"))
          .to eq(caption)
      end

      it "keeps an emphasised caption without the simg tag" do
        text = "<simg>\n*Figure 10 – Courbes de réponse en fréquence en " \
               "boucle ouverte; diagramme de Bode*</simg>"

        expect(subject.parse_anchor_tag(text, "351")).to eq(
          "*Figure 10 – Courbes de réponse en fréquence en boucle " \
          "ouverte; diagramme de Bode*",
        )
      end
    end

    context "when issue examples contain partially converted lists" do
      it "preserves the exact #124 fragment without li tags" do
        text = "where the element stem:[a]~stem:[ij]~ is:\r\n" \
               "<ul style=\"list-style: none;\">\r\n*"

        result = subject.replace_newlines(subject.parse_anchor_tag(text, "131"))
        expect(result).to eq(
          "where the element stem:[a]~stem:[ij]~ is:\n\n*",
        )
      end

      { "definition" => 7, "note" => 5 }.each do |part, count|
        it "preserves the exact #117 #{part} from its YAML attachment" do
          text = File.read(File.join(
                             fixture_dir, "issue-117-#{part}-original.html"
                           ))
          result = subject.replace_newlines(
            subject.parse_anchor_tag(text, "845"),
          )

          expect(result).not_to match(/<\/?(?:ul|li|p)\b|\r/)
          expect(result.scan(/^\* /).size).to eq(count)
          expect(result).not_to match(/^\*[ \t]*$/)
          formulas = result.scan(/stem:\[(?:(?!stem:\[)[^\n])*/).map(&:strip)
          expect(formulas).to eq(
            CGI.unescapeHTML(text).gsub(/\r\n?/, "\n")
              .gsub(/<ul[^>]*>/, "\n\n")
              .scan(/stem:\[(?:(?!stem:\[)[^\n])*/).map(&:strip),
          )
          expect(result).to include("if stem:[( ")
          expect(result).to include("6 // 29 )^3]")
        end
      end
    end

    # glossarist/iev-data#124 and #117
    context "when text contains lists" do
      it "puts a styled ul on its own lines and normalises CRLF" do
        text = "where the element stem:[a]~stem:[ij]~ is:\r\n" \
               "<ul style=\"list-style: none;\">\r\n" \
               "<li>a</li>\r\n<li>b</li>\r\n</ul>\r\nend"

        result = subject.replace_newlines(subject.parse_anchor_tag(text, "131"))
        expect(result).to eq(
          "where the element stem:[a]~stem:[ij]~ is:\n\n* a\n* b\n\nend",
        )
      end

      it "separates a list that directly follows text" do
        text = 'equations:<ul style="list-style-type:none;">' \
               "<li>x</li></ul>where"

        expect(subject.replace_newlines(subject.parse_anchor_tag(text, "845")))
          .to eq("equations:\n\n* x\n\nwhere")
      end

      it "nests lists with deeper markers" do
        text = "<ol><li>a<ul><li>b</li></ul></li><li>c</li></ol>"

        expect(subject.replace_newlines(subject.parse_anchor_tag(text, "103")))
          .to eq(". a\n** b\n. c")
      end

      # glossarist/iev-data#117: definition and note of 845-23-076 (en),
      # prose and formulas taken from the issue attachment
      it "converts the 845-23-076 definition lists to AsciiDoc" do
        text = File.read(
          File.join(fixture_dir, "issue-117-845-23-076-eng-definition.html"),
        )

        result = subject.replace_newlines(subject.parse_anchor_tag(text, "845"))
        expect(result).not_to match(/<\/?(ul|li|p)\b|\r/)
        expect(result.scan(/^\* /).size).to eq(7)
        expect(result).to include(
          "quantities defined by the equations:\n\n* stem:[[[L,*,=,116,f,",
        ).and include(
          "( X // X_n )^(1 // 3)]\n+\n" \
          "if stem:[( X // X_n ) > ( 6 // 29 )^3]\n" \
          "* stem:[f ( X // X_n ) = ( 841 // 108 )",
        )
        expect(result).to include("\n\nand\n\n* stem:[f ( Z // Z_n )")
        expect(result).to end_with(
          "\n\nand stem:[X], stem:[Y], stem:[Z] describe the colour stimulus " \
          "considered and stem:[X]~n~, stem:[Y]~n~, stem:[Z]~n~ describe a " \
          "specified white achromatic stimulus",
        )
      end

      it "converts the 845-23-076 note lists to AsciiDoc" do
        text = File.read(
          File.join(fixture_dir, "issue-117-845-23-076-eng-note.html"),
        )

        result = subject.replace_newlines(subject.parse_anchor_tag(text, "845"))
        expect(result).not_to match(/<\/?(ul|li|p)\b|\r/)
        expect(result).to start_with(
          "Approximate correlates of lightness, chroma, and hue can be " \
          "calculated as follows:\n\nCIE 1976 lightness:\n\n" \
          "* stem:[L^( ** ) = 116 f ( Y // Y_n ) - 16]\n\nwhere\n\n",
        )
        expect(result).to end_with(
          "CIE 1976 stem:[a], stem:[b] hue angle:\n\n" \
          "* stem:[h_((ab)) = arctan ( b^( * ) // a^( * ) )]",
        )
      end

      # glossarist/iev-data#17 (103-02-01, en)
      it "keeps formulas attached to their ordered list items" do
        text = File.read(File.join(fixture_dir, "issue-17-103-02-01.html"))

        result = Iev::Converter.mathml_to_asciimath(
          subject.replace_newlines(subject.parse_anchor_tag(text, "103")),
        )
        items = result[/^\. .*?(?=\n\nNote 1)/m]
        expect(items.scan(/^\. /).size).to eq(2)
        expect(items.scan(/^\+$/).size).to eq(2)
        expect(items).to match(/^\. for stem:\[n\] .*:\n\+\nstem:\[bar\(X\)/)
        expect(items).to match(/^\. for a quantity .*:\n\+\nstem:\[bar\(X\)/)
        expect(items).not_to include("<")
        expect(result).to include("Note 1 to entry")
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

  # iev-data #121, #123, #127
  describe "#parse_anchor_tag inline markup" do
    it "converts <strong> like <b> (#121)" do
      expect(subject.parse_anchor_tag("a <strong>bold</strong> word", "112"))
        .to eq("a *bold* word")
    end

    it "converts <strong> inside table cells (#121)" do
      text = "<table><tr><td><strong><span>Unit name</span></strong>" \
             "</td></tr></table>"

      expect(subject.parse_anchor_tag(text, "112"))
        .to eq("<table><tr><td>*Unit name*</td></tr></table>")
    end

    it "converts <u> to an underline role, keeping stem content (#123)" do
      text = "phasors <u>stem:[*D*]</u> and <u>E</u>s"

      expect(subject.parse_anchor_tag(text, "121"))
        .to eq("phasors [.underline]##stem:[*D*]## and [.underline]##E##s")
    end

    it "drops an empty <u> (#123)" do
      expect(subject.parse_anchor_tag("a<u></u>b", "121")).to eq("ab")
    end

    it "drops image-map <map>/<area> hotspots but keeps the image (#127)" do
      text = '<simg usemap="#m"/$file/447-02-01-Fig1-en.png>' \
             '<map name="m"> <area title="x" href="IEV447-02-03" ' \
             'shape="rect" coords="1,2,3,4" alt="x"> <area title="y" ' \
             'href="IEV447-02-10" shape="rect" coords="" alt="y"></map>' \
             "<p><b>Figure 1 – Diagram</b></p></simg>"

      result = subject.parse_anchor_tag(text, "447")
      expect(result).to start_with(
        "image::/assets/images/parts/447/447-02-01-Fig1-en.png[",
      )
      expect(result).not_to match(/<map|<area|coords/)
    end

    it "drops a <map> that follows a plain <img> (#127)" do
      text = '<img src="a.png" usemap="#image-map">' \
             '<map name="image-map"><area title="t" shape="rect" ' \
             'coords="1,2,3,4" alt="t"></map><b>Key</b>'

      expect(subject.parse_anchor_tag(text, "485"))
        .to eq("image::/assets/images/parts/485/a.png[]*Key*")
    end
  end
end
