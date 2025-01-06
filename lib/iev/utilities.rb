# frozen_string_literal: true

module Iev
  module Utilities
    SIMG_PATH_REGEX = "<simg .*\\/\\$file\\/([\\d\\-\\w\.]+)>"
    FIGURE_ONE_REGEX =
      '<p><b>\\s*Figure\\s+(\\d)\\s+[–-]\\s+(.+)\\s*<\\/b>(<\\/p>)?'
    FIGURE_TWO_REGEX = "#{FIGURE_ONE_REGEX}\\s*#{FIGURE_ONE_REGEX}".freeze
    IMAGE_PATH_PREFIX = "image::/assets/images/parts"

    def parse_anchor_tag(text, term_domain)
      return unless text

      # Convert IEV term references
      # Convert href links
      # Need to take care of this pattern:
      #  `inverse de la <a href="IEV103-06-01">période<a>`
      text.gsub(
        %r{<a href="?(IEV)\s*(\d\d\d-\d\d-\d\d\d?)"?>(.*?)</?a>},
        '{{\3, \1:\2}}',
      ).gsub(
        %r{<a href="?\s*(\d\d\d-\d\d-\d\d\d?)"?>(.*?)</?a>},
        '{{\3, IEV:\2}}',
      ).gsub(
        # To handle <a> tags without ending tag like
        #  `Voir <a href=IEV103-05-21>IEV 103-05-21`
        #  for concept '702-03-11' in `fr`
        /<a href="?(IEV)?\s*(\d\d\d-\d\d-\d\d\d?)"?>(.*?)$/,
        '{{\3, IEV:\2}}',
      ).gsub(
        %r{<a href="?([^<>]*?)"?>(.*?)</a>},
        '\1[\2]',
      ).gsub(
        Regexp.new([SIMG_PATH_REGEX, '\\s*', FIGURE_TWO_REGEX].join),
        "#{IMAGE_PATH_PREFIX}/#{term_domain}/\\1[Figure \\2 - \\3; \\6]",
      ).gsub(
        Regexp.new([SIMG_PATH_REGEX, '\\s*', FIGURE_ONE_REGEX].join),
        "#{IMAGE_PATH_PREFIX}/#{term_domain}/\\1[Figure \\2 - \\3]",
      ).gsub(
        /<img\s+([^<>]+?)\s*>/,
        "#{IMAGE_PATH_PREFIX}/#{term_domain}/\\1[]",
      ).gsub(
        /<br>/,
        "\n",
      ).gsub(
        %r{<b>(.*?)</b>},
        '*\\1*',
      )
    end

    def replace_newlines(input)
      input.gsub('\n', "\n\n")
        .gsub(/<[pbr]+>/, "\n\n")
        .gsub(/\s*\n[\n\s]+/, "\n\n")
        .strip
    end
  end
end
