# frozen_string_literal: true

module Iev
  # Hoists IEV figure references into dataset-shared Figure entities.
  #
  # IEV source data carries figures as inline SIMG tags, which Utilities
  # rewrites to AsciiDoc image macros (+image::/assets/images/parts/{area}/
  # FILE[Figure N - caption]+). This builder walks every concept's
  # localizations, finds those image macros, promotes each to a
  # dataset-shared Glossarist::Figure entity, and rewrites the inline text
  # to a V3 figure mention (+{{fig:id, display}}+).
  #
  # The Figure entity is shared across concepts and languages — captions
  # from different localizations merge into the same {lang => text} hash.
  # The structural link from concept to figure is a FigureReference entry
  # on ManagedConceptData#figures.
  #
  # Extraction is destructive: it mutates DetailedDefinition#content and
  # appends FigureReference entries. Returns the unique Figure entities so
  # the exporter can persist them to figures/{id}.yaml.
  module FigureBuilder
    # URL path prefix emitted by Utilities when converting SIMG tags.
    # Kept in sync with Utilities::IMAGE_PATH_PREFIX (without the macro).
    PATH_PREFIX = "/assets/images/parts"
    private_constant :PATH_PREFIX

    # Matches AsciiDoc image macros emitted by Utilities#process_simg_figures.
    IMAGE_MACRO_REGEX = /
      image::#{Regexp.escape(PATH_PREFIX)}
      \/(?<area>\d+)\/(?<file>[\w.-]+)\[(?<caption>[^\]]*)\]
    /x

    # Captures "Figure N" label and the trailing caption text.
    CAPTION_REGEX = /\A(?<label>Figure\s+\d+)\s*[–-]\s*(?<text>.+)\z/m

    module_function

    # @param collection [Glossarist::ManagedConceptCollection]
    # @return [Array<Glossarist::Figure>] unique figures, sorted by id
    def extract!(collection)
      figures_by_id = {}

      collection.each do |concept|
        concept.localizations.each do |l10n|
          process_localization(l10n, concept, figures_by_id)
        end
      end

      figures_by_id.values.sort_by(&:id)
    end

    def process_localization(l10n, concept, figures_by_id)
      lang = l10n.data&.language_code
      return unless lang && lang.length == 3

      Glossarist::ConceptData.detailed_definition_fields.each do |field|
        process_field(l10n, field, lang, concept, figures_by_id)
      end
    end
    private_class_method :process_localization

    def process_field(l10n, field, lang, concept, figures_by_id)
      l10n.data.public_send(field).each do |dd|
        next unless dd.content&.include?("image::")

        rewritten, hits = extract_from_text(dd.content, lang)
        next if hits.empty?

        dd.content = rewritten
        hits.each { |hit| register_figure(hit, concept, figures_by_id) }
      end
    end
    private_class_method :process_field

    # @return [Array<(String, Array<Hash>)>] rewritten text and per-match
    #   figure descriptors ({ id:, identifier:, caption:, lang:, image: })
    def extract_from_text(text, lang)
      hits = []
      rewritten = text.gsub(IMAGE_MACRO_REGEX) do
        hit = build_hit(Regexp.last_match, lang)
        hits << hit
        mention_for(hit)
      end
      [rewritten, hits]
    end
    private_class_method :extract_from_text

    def build_hit(match, lang)
      identifier, caption = parse_caption(match[:caption])
      {
        id: figure_id_for(match[:file]),
        identifier: identifier,
        caption: caption,
        lang: lang,
        image: build_image(match[:area], match[:file]),
      }
    end
    private_class_method :build_hit

    def build_image(area, file)
      Glossarist::FigureImage.new(
        src: "#{PATH_PREFIX}/#{area}/#{file}",
        format: format_for(file),
      )
    end
    private_class_method :build_image

    def parse_caption(bracket)
      stripped = bracket.to_s.strip
      return [nil, nil] if stripped.empty?

      if (m = stripped.match(CAPTION_REGEX))
        label = m[:label].gsub(/\s+/, " ")
        [label, m[:text].strip]
      elsif stripped.match?(/\AFigure\s+\d+\z/)
        [stripped, nil]
      else
        [nil, stripped]
      end
    end
    private_class_method :parse_caption

    def figure_id_for(file)
      "fig-#{file.sub(/\.[^.]+\z/, '')}"
    end
    private_class_method :figure_id_for

    def format_for(file)
      File.extname(file).delete_prefix(".").downcase
    end
    private_class_method :format_for

    def mention_for(hit)
      parts = [hit[:identifier], hit[:caption]].compact
      return "{{fig:#{hit[:id]}}}" if parts.empty?

      "{{fig:#{hit[:id]}, #{parts.join(' - ')}}}"
    end
    private_class_method :mention_for

    # Add or merge a figure descriptor into the shared index, and ensure the
    # concept carries a FigureReference to it.
    def register_figure(hit, concept, figures_by_id)
      figure = figures_by_id[hit[:id]] ||= build_figure(hit)
      merge_caption!(figure, hit)
      add_image_if_missing(figure, hit[:image])
      add_figure_reference(concept, hit[:id], hit[:identifier])
    end
    private_class_method :register_figure

    def build_figure(hit)
      Glossarist::Figure.new(
        id: hit[:id],
        identifier: hit[:identifier],
        images: [],
        caption: {},
      )
    end
    private_class_method :build_figure

    def merge_caption!(figure, hit)
      return unless hit[:caption]

      figure.caption ||= {}
      figure.caption[hit[:lang]] ||= hit[:caption]
    end
    private_class_method :merge_caption!

    def add_image_if_missing(figure, image)
      return if figure.images.any? { |i| i.src == image.src }

      figure.images << image
    end
    private_class_method :add_image_if_missing

    def add_figure_reference(concept, figure_id, display)
      refs = Array(concept.data.figures)
      return if refs.any? { |r| r.entity_id == figure_id }

      concept.data.figures = refs + [
        Glossarist::FigureReference.new(entity_id: figure_id, display: display),
      ]
    end
    private_class_method :add_figure_reference
  end
end
