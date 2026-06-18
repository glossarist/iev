# frozen_string_literal: true

require "spec_helper"

RSpec.describe Iev::FigureBuilder do
  let(:image_macro) do
    "image::/assets/images/parts/103/103-01-02en.gif[Figure 1 - Waveform]"
  end

  let(:bare_macro) do
    "image::/assets/images/parts/103/103-01-02en.gif[]"
  end

  describe ".extract!" do
    it "extracts a figure from definition content" do
      concept = build_concept("103-01-02", "eng",
                              definition: "See #{image_macro} below.")

      figures = described_class.extract!(collection_with(concept))

      expect(figures.length).to eq(1)
      figure = figures.first
      expect(figure.id).to eq("fig-103-01-02en")
      expect(figure.identifier).to eq("Figure 1")
      expect(figure.caption["eng"]).to eq("Waveform")
      expect(figure.images.first.src).to eq(
        "/assets/images/parts/103/103-01-02en.gif",
      )
      expect(figure.images.first.format).to eq("gif")
    end

    it "rewrites image macro to figure mention" do
      concept = build_concept("103-01-02", "eng",
                              definition: "See #{image_macro} below.")

      described_class.extract!(collection_with(concept))

      rewritten = concept.localization("eng").data.definition.first.content
      expect(rewritten).to eq(
        "See {{fig:fig-103-01-02en, Figure 1 - Waveform}} below.",
      )
    end

    it "adds a FigureReference to the managed concept" do
      concept = build_concept("103-01-02", "eng", definition: image_macro)

      described_class.extract!(collection_with(concept))

      refs = concept.data.figures
      expect(refs.length).to eq(1)
      expect(refs.first.entity_id).to eq("fig-103-01-02en")
      expect(refs.first.display).to eq("Figure 1")
    end

    it "deduplicates FigureReference on the same concept" do
      concept = build_concept("103-01-02", "eng",
                              definition: "#{image_macro} and #{image_macro}")

      described_class.extract!(collection_with(concept))

      expect(concept.data.figures.length).to eq(1)
    end

    it "shares one Figure entity across concepts" do
      c1 = build_concept("103-01-02", "eng", definition: image_macro)
      c2 = build_concept("103-01-03", "eng", definition: image_macro)

      figures = described_class.extract!(collection_with(c1, c2))

      expect(figures.length).to eq(1)
      c1_id = c1.data.figures.first.entity_id
      expect(c1_id).to eq(c2.data.figures.first.entity_id)
    end

    it "merges captions across languages on the same figure" do
      concept = build_concept("103-01-02", "eng", definition: image_macro)
      fr_macro = "Voir image::/assets/images/parts/103/" \
                 "103-01-02en.gif[Figure 1 - Forme d'onde]."
      fr_l10n = build_l10n("103-01-02", "fra", definition: fr_macro)
      concept.add_l10n(fr_l10n)

      figures = described_class.extract!(collection_with(concept))

      expect(figures.first.caption["eng"]).to eq("Waveform")
      expect(figures.first.caption["fra"]).to eq("Forme d'onde")
    end

    it "handles image macro without caption" do
      concept = build_concept("103-01-02", "eng",
                              definition: "An #{bare_macro}.")

      figures = described_class.extract!(collection_with(concept))

      expect(figures.length).to eq(1)
      expect(figures.first.identifier).to be_nil
      expect(figures.first.caption).to eq({})
      expect(concept.localization("eng").data.definition.first.content).to eq(
        "An {{fig:fig-103-01-02en}}.",
      )
    end

    it "scans examples and notes in addition to definition" do
      concept = build_concept("103-01-02", "eng",
                              definition: "Plain text.",
                              examples: ["Example: #{image_macro}"],
                              notes: ["Note: #{image_macro}"])

      figures = described_class.extract!(collection_with(concept))

      expect(figures.length).to eq(1)
      examples = concept.localization("eng").data.examples
      notes = concept.localization("eng").data.notes
      expect(examples.first.content).to include("{{fig:fig-103-01-02en")
      expect(notes.first.content).to include("{{fig:fig-103-01-02en")
    end

    it "returns empty array when no image macros are present" do
      concept = build_concept("103-01-02", "eng", definition: "Just text.")

      figures = described_class.extract!(collection_with(concept))

      expect(figures).to eq([])
    end

    it "skips localizations without a 3-char language code" do
      concept = build_concept("103-01-02", "eng", definition: image_macro)
      bad_l10n = build_l10n("103-01-02", "", definition: image_macro)
      concept.add_l10n(bad_l10n)

      figures = described_class.extract!(collection_with(concept))

      expect(figures.length).to eq(1)
    end

    it "infers format from file extension" do
      png = "image::/assets/images/parts/103/figure.png[Figure 1 - PNG]"
      concept = build_concept("103-01-02", "eng", definition: png)

      figures = described_class.extract!(collection_with(concept))

      expect(figures.first.images.first.format).to eq("png")
    end

    it "returns figures sorted by id" do
      zebra = "image::/assets/images/parts/103/zebra.png[]"
      apple = "image::/assets/images/parts/103/apple.png[]"
      c1 = build_concept("103-01-02", "eng", definition: zebra)
      c2 = build_concept("103-01-03", "eng", definition: apple)

      figures = described_class.extract!(collection_with(c1, c2))

      expect(figures.map(&:id)).to eq(figures.map(&:id).sort)
    end

    it "treats 'Figure N' label only (no caption) as identifier" do
      macro = "image::/assets/images/parts/103/103-01-02en.gif[Figure 5]"
      concept = build_concept("103-01-02", "eng", definition: macro)

      figure = described_class.extract!(collection_with(concept)).first

      expect(figure.identifier).to eq("Figure 5")
      expect(figure.caption).to eq({})
    end

    it "normalizes whitespace in figure label" do
      macro = "image::/assets/images/parts/103/" \
              "103-01-02en.gif[Figure  3   - Caption]"
      concept = build_concept("103-01-02", "eng", definition: macro)

      figure = described_class.extract!(collection_with(concept)).first

      expect(figure.identifier).to eq("Figure 3")
      expect(figure.caption["eng"]).to eq("Caption")
    end
  end

  def build_concept(id, lang, definition: nil, examples: [], notes: [])
    mc = Glossarist::ManagedConcept.new(data: { "id" => id })
    l10n = build_l10n(id, lang, definition: definition, examples: examples,
                                notes: notes)
    mc.add_l10n(l10n)
    mc
  end

  def build_l10n(id, lang, definition: nil, examples: [], notes: [])
    l10n = Glossarist::LocalizedConcept.new
    l10n.data.id = id
    l10n.data.language_code = lang
    assign_definition(l10n, definition) if definition
    l10n.data.examples = to_detailed(examples)
    l10n.data.notes = to_detailed(notes)
    l10n
  end

  def assign_definition(l10n, content)
    dd = Glossarist::DetailedDefinition.new(content: content)
    l10n.data.definition = [dd]
  end

  def to_detailed(items)
    Array(items).map { |e| Glossarist::DetailedDefinition.new(content: e) }
  end

  def collection_with(*concepts)
    collection = Glossarist::ManagedConceptCollection.new
    concepts.each { |c| collection.store(c) }
    collection
  end
end
