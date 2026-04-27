# frozen_string_literal: true

module Iev
  module Utilities
    IMAGE_PATH_PREFIX = "image::/assets/images/parts"
    IEV_CODE_RE = /\A(IEV)?\s*(\d{2,3}-\d{2,3}-\d{2,3})\z/

    # SIMG/Figure patterns — custom IEV XML, pre-processed before Nokogiri
    SIMG_PATH_REGEX = /<simg .*\/\$file\/([\d\-\w.]+)>/
    FIGURE_ONE_REGEX = '<p><b>\\s*Figure\\s+(\\d)\\s+[–-]\\s+(.+)\\s*<\\/b>(<\\/p>)?'
    FIGURE_TWO_REGEX = "#{FIGURE_ONE_REGEX}\\s*#{FIGURE_ONE_REGEX}".freeze

    def parse_anchor_tag(text, term_domain)
      return nil if text.nil?

      text = process_simg_figures(text, term_domain)
      text = fix_unquoted_href(text)

      doc = Nokogiri::HTML::DocumentFragment.parse(text)
      nodes_to_adoc(doc.children, term_domain)
    end

    def replace_newlines(input)
      input
        .gsub('\n', "\n\n")
        .gsub(/<[pbr]+>/, "\n\n")
        .gsub(/<br\s*\/?>/, "\n\n")
        .gsub(/\s*\n[\n\s]+/, "\n\n")
        .strip
    end

    private

    # IEV data has unquoted href with spaces, e.g.
    #   <a href=IEV 102-01-10>...</a>
    # Nokogiri stops at first space, so add quotes
    # to preserve the full value.
    def fix_unquoted_href(text)
      text.gsub(/href=([^"'\s>][^"'>]*[^"'>\s])\b/) do
        val = Regexp.last_match(1).strip
        "href=\"#{val}\""
      end
    end

    def process_simg_figures(text, term_domain)
      text = text.gsub(
        Regexp.new([SIMG_PATH_REGEX.source, '\s*', FIGURE_TWO_REGEX].join),
        "#{IMAGE_PATH_PREFIX}/#{term_domain}/\\1[Figure \\2 - \\3; \\6 - \\7]",
      )
      text = text.gsub(
        Regexp.new([SIMG_PATH_REGEX.source, '\s*', FIGURE_ONE_REGEX].join),
        "#{IMAGE_PATH_PREFIX}/#{term_domain}/\\1[Figure \\2 - \\3]",
      )
      text.gsub(SIMG_PATH_REGEX, "#{IMAGE_PATH_PREFIX}/#{term_domain}/\\1[]")
    end

    def nodes_to_adoc(nodes, term_domain)
      nodes.map { |n| node_to_adoc(n, term_domain) }.join
    end

    def node_to_adoc(node, term_domain)
      case node
      when Nokogiri::XML::Text
        node.text
      when Nokogiri::XML::Comment
        ""
      when Nokogiri::XML::Element
        element_to_adoc(node, term_domain)
      else
        ""
      end
    end

    def element_to_adoc(node, term_domain)
      inner = nodes_to_adoc(node.children, term_domain)

      case node.name
      when "a"
        convert_link(node, inner)
      when "b"
        "*#{inner}*"
      when "br"
        "\n"
      when "img"
        src = node["src"] || node.attributes.keys.first.to_s
        "#{IMAGE_PATH_PREFIX}/#{term_domain}/#{src}[]"
      when "p", "div", "span"
        inner
      else
        node.to_s
      end
    end

    def convert_link(node, inner)
      href = (node["href"] || "").to_s.strip

      if href.match?(IEV_CODE_RE)
        iev_code = href.sub(/\AIEV\s*/, "")
        "{{#{inner}, IEV:#{iev_code}}}"
      elsif !href.empty?
        "#{href}[#{inner}]"
      else
        inner
      end
    end
  end
end
