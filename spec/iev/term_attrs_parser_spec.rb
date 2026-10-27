# frozen_string_literal: true

# (c) Copyright 2020 Ribose Inc.
#

RSpec.describe Iev::TermAttrsParser do
  # Parses :string metadata or example description.
  subject do
    example = RSpec.current_example
    attributes_str = example.metadata[:string] || example.description
    described_class.new(attributes_str)
  end

  describe "gender" do
    example "f" do
      expect(subject.gender).to eq("f")
    end

    example "m" do
      expect(subject.gender).to eq("m")
    end

    example "n" do
      expect(subject.gender).to eq("n")
    end

    it "works for empty strings", string: "" do
      expect(subject.gender).to be(nil)
    end

    it "works for strings which do not specify gender", string: "a whatever" do
      expect(subject.gender).to be(nil)
    end

    it "allows comma as a separator", string: "m, whatever" do
      expect(subject.gender).to eq("m")
    end

    it "is not fooled with longer sentences (begin/end of word)",
       string: "noun" do
      expect(subject.gender).to be(nil)
    end

    it "cannot be placed inside brackets", string: "(m)" do
      expect(subject.gender).to eq("m")
    end
  end

  describe "plurality" do
    example "pl" do
      expect(subject.plurality).to eq("plural")
    end

    example "f pl" do
      expect(subject.plurality).to eq("plural")
    end
    example "m pl" do
      expect(subject.plurality).to eq("plural")
    end
    example "n pl" do
      expect(subject.plurality).to eq("plural")
    end

    it "works for empty strings", string: "" do
      expect(subject.plurality).to be(nil)
    end

    it "works for strings which do not specify plurality",
       string: "a whatever" do
      expect(subject.plurality).to be(nil)
    end

    it "allows comma as a separator", string: "m,pl" do
      expect(subject.plurality).to eq("plural")
    end

    it "is not fooled with longer sentences (begin/end of word)",
       string: "what a plapl" do
      expect(subject.plurality).to be(nil)
    end

    it "always sets plurality if gender is specified", string: "f" do
      expect(subject.plurality).to eq("singular")
    end

    it "always sets plurality if gender is specified", string: "m" do
      expect(subject.plurality).to eq("singular")
    end

    it "always sets plurality if gender is specified", string: "n" do
      expect(subject.plurality).to eq("singular")
    end

    it "cannot be placed inside brackets", string: "(pl)" do
      expect(subject.plurality).to eq("plural")
    end
  end

  describe "part of speech" do
    example "adj" do
      expect(subject.part_of_speech).to eq("adj")
    end

    # Polish "prp adj" (192-10-06) is adjectival; "prp" is not mapped.
    example "prp adj" do
      expect(subject.part_of_speech).to eq("adj")
    end

    example "noun" do
      expect(subject.part_of_speech).to eq("noun")
    end

    example "verb" do
      expect(subject.part_of_speech).to eq("verb")
    end

    example "名詞" do
      expect(subject.part_of_speech).to eq("noun")
    end

    example "動詞" do
      expect(subject.part_of_speech).to eq("verb")
    end

    example "形容詞" do
      expect(subject.part_of_speech).to eq("adj")
    end

    example "형용사" do
      expect(subject.part_of_speech).to eq("adj")
    end

    example "Adjektiv" do
      expect(subject.part_of_speech).to eq("adj")
    end

    it "works for empty strings", string: "" do
      expect(subject.part_of_speech).to be(nil)
    end

    it "works for strings which do not specify p.o.s.", string: "a whatever" do
      expect(subject.part_of_speech).to be(nil)
    end

    it "allows comma as a separator", string: "adj, whatever" do
      expect(subject.part_of_speech).to eq("adj")
    end

    it "is not fooled with longer sentences (begin/end of word)",
       string: "adjunction radj" do
      expect(subject.part_of_speech).to be(nil)
    end
  end

  describe "usage info" do
    it "a string <info>" do
      expect(subject.usage_info).to eq("info")
    end

    it "<only info>" do
      expect(subject.usage_info).to eq("only info")
    end

    it "<  info with extra spaces\t>" do
      expect(subject.usage_info).to eq("info with extra spaces")
    end

    it "works for empty strings", string: "" do
      expect(subject.usage_info).to be(nil)
    end

    it "works for strings which do not specify usage info",
       string: "a whatever" do
      expect(subject.usage_info).to be(nil)
    end

    it "supports full-width signs", string: "a string \uFF1Cinfo\uFF1E" do
      expect(subject.usage_info).to eq("info")
    end

    it "disallows mixing regular and full-width signs",
       string: "a string \uFF1Cinfo>" do
      expect(subject.usage_info).to be(nil)
    end

    # #126: HTML tags in TERMATTRIBUTE should not interfere with usage_info
    it "strips HTML <sup> tags and extracts usage_info",
       string: "<telecommunications>" do
      expect(subject.usage_info).to eq("telecommunications")
    end

    it "strips HTML <i> tags before extracting usage_info",
       string: "genau <i>(exakt)" do
      # After stripping <i>, no angle-bracketed usage_info remains
      expect(subject.usage_info).to be(nil)
    end

    it "handles attribute string with <sup> tags",
       string: "kibibajt = 2<sup>20</sup> B" do
      # After stripping <sup>, no angle-bracketed usage_info remains
      expect(subject.usage_info).to be(nil)
    end
  end

  describe "geographical area" do
    example "US" do
      expect(subject.geographical_area).to eq("US")
    end

    example "DE" do
      expect(subject.geographical_area).to eq("DE")
    end

    it "requires capital letters", string: "us" do
      expect(subject.geographical_area).to be(nil)
    end

    it "works for empty strings", string: "" do
      expect(subject.geographical_area).to be(nil)
    end

    it "works for strings which do not specify area",
       string: "a whatever" do
      expect(subject.geographical_area).to be(nil)
    end

    it "is not fooled with longer words",
       string: "THUS" do
      expect(subject.geographical_area).to be(nil)
    end
  end

  describe "prefix" do
    example "Präfix" do
      expect(subject.prefix).to eq("Präfix")
    end

    example "prefix" do
      expect(subject.prefix).to eq("prefix")
    end

    example "préfixe" do
      expect(subject.prefix).to eq("préfixe")
    end

    example "接尾語" do
      expect(subject.prefix).to eq("接尾語")
    end

    example "접두사" do
      expect(subject.prefix).to eq("접두사")
    end

    example "przedrostek" do
      expect(subject.prefix).to eq("przedrostek")
    end

    example "prefixo" do
      expect(subject.prefix).to eq("prefixo")
    end

    example "词头" do
      expect(subject.prefix).to eq("词头")
    end

    it "works for empty strings", string: "" do
      expect(subject.prefix).to be(nil)
    end

    it "works for strings which do not specify prefix",
       string: "a whatever" do
      expect(subject.prefix).to be(nil)
    end

    it "is not fooled with longer words",
       string: "prefixed" do
      expect(subject.prefix).to be(nil)
    end
  end

  # iev-data #33: every TERMATTRIBUTE variant listed in the issue.
  describe "issue #33 variants" do
    include IevHtmlPartialsHelpers

    let(:variants) do
      path = File.expand_path(
        "../fixtures/iev_term_attributes/issue_33_variants.txt", __dir__
      )
      File.readlines(path, chomp: true)
    end

    it "parses every variant in the issue without raising" do
      expect(variants.size).to be > 7000
      expect do
        variants.each { |v| parse_term_attributes(v) }
      end.not_to raise_error
    end

    it "extracts usage info from every closed <...> variant" do
      closed = variants.grep(/&lt;.+?&gt;|<[^<>]+>/)
      expect(closed.size).to be > 4000

      missing = closed.reject do |variant|
        attrs = parse_term_attributes(variant)
        # HTML-only and parenthesised qualifiers are not angle usage info.
        !attrs.src_str.match?(/<[^<>]+>/) || attrs.usage_info
      end
      expect(missing).to be_empty
    end

    it "never reads a gender out of the usage info text" do
      letters = Iev::TermAttrsParser::CYRILLIC_GENDERS
      leaks = variants.filter_map do |v|
        attrs = parse_term_attributes(v)
        next unless attrs.usage_info && attrs.gender

        outside = attrs.src_str.split(/[<\uFF1C].*?[>\uFF1E]/).join(" ")
        accepted = [attrs.gender, letters.key(attrs.gender)].compact
        v unless accepted.any? { |g| outside.match?(/\b#{g}\b/) }
      end

      expect(leaks).to be_empty
    end

    {
      "<de <i>n</i> vecteurs> m" => ["m", "de n vecteurs", nil],
      "<eines Betriebsmittels> f" => ["f", "eines Betriebsmittels", nil],
      "<modelu referencyjnego ISO> f sg" =>
        ["f", "modelu referencyjnego ISO", "singular"],
      "<bei Zentralkanalsignalisierung> f pl" =>
        ["f", "bei Zentralkanalsignalisierung", "plural"],
      "<PN споја> м јд" => ["m", "PN споја", "singular"],
      "<(1)> ж јд" => ["f", "(1)", "singular"],
      "<у електроенергетском систему> с јд" =>
        ["n", "у електроенергетском систему", "singular"],
      "<у рачунарским мрежама> ж мн" =>
        ["f", "у рачунарским мрежама", "plural"],
      "<за уређај диференцијалне струје> м мн" =>
        ["m", "за уређај диференцијалне струје", "plural"],
      "<ogniwa paliwowego> m" => ["m", "ogniwa paliwowego", "singular"],
    }.each do |input, (gender, info, plurality)|
      it "reads #{input.inspect}", string: input do
        attrs = parse_term_attributes(input)
        expect([attrs.gender, attrs.usage_info, attrs.plurality])
          .to eq([gender, info, plurality ||
                  (gender ? "singular" : nil)])
      end
    end

    {
      "<eines Messrelais oder einer Schutzeinrichtung> Verb" => "verb",
      "<3> verbe" => "verb",
      "<para um relé de medição> verbo" => "verb",
      "<측정 계전기 또는 보호 장비> 동사" => "verb",
      "<요소 계전기>, 명사" => "noun",
      "<у рачунарским мрежама> глагол" => "verb",
      "<في البرمجة> فعل" => "verb",
      "<装置> 動詞" => "verb",
      "<作用> 动词" => "verb",
      "<elettrostaticamente> agg" => "adj",
      "<проводан: IEV 151-15-56> придев" => "adj",
      "<bezüglich der Darstellung von Information> Adjektiv" => "adj",
      "<Begeitheizung> adjektivisch" => "adj",
    }.each do |input, pos|
      it "maps the part of speech in #{input.inspect}" do
        attrs = parse_term_attributes(input)
        expect(attrs.part_of_speech).to eq(pos)
        expect(attrs.to_grammar_info.part_of_speech).to eq(pos)
        expect(attrs.usage_info).not_to be_nil
      end
    end

    it "reads a Cyrillic prefix keyword" do
      attrs = parse_term_attributes("<електро: IEV 151-11-04> префикс")
      expect(attrs.prefix).to eq("префикс")
      expect(attrs.usage_info).to eq("електро: IEV 151-11-04")
    end

    it "keeps bare gender and parts of speech" do
      expect(parse_term_attributes("f").gender).to eq("f")
      expect(parse_term_attributes("adj").part_of_speech).to eq("adj")
      expect(parse_term_attributes("m").to_grammar_info.gender).to eq(["m"])
    end

    # Open questions (issue #33). These values are intentionally NOT turned
    # into attributes until the representation is decided; the specs pin
    # that nothing is invented from them.
    describe "unresolved variants" do
      [
        "(of an amplifier)", # Q1 parenthesised qualifier
        "(d'un signal) f", # Q1 with gender
        "(1)", # Q2 homograph number
        "(deprecated)", # Q3 status word in attributes
        "(abgelehnt)",
        "(abréviation)", # Q4 abbreviation marker
        "qualificatif", # Q5 qualifier word class
        "限定词",
        "<신호 장비&gt", # Q6 truncated closing sign
        "<電子ネットワークの＞", # Q6 mixed-width signs
      ].each do |input|
        it "extracts no usage info or surprise grammar from #{input.inspect}" do
          attrs = parse_term_attributes(input)
          expect(attrs.usage_info).to be_nil
          expect(attrs.part_of_speech).to be_nil
        end
      end

      it "still reads the gender next to a parenthesised qualifier" do
        expect(parse_term_attributes("(d'un signal) f").gender).to eq("f")
      end
    end
  end
end
