# frozen_string_literal: true

module Iev
  module Utilities
    IMAGE_PATH_PREFIX = "image::/assets/images/parts"
    TABLE_TAGS = %w[table thead tbody tfoot tr td th caption].freeze
    IEV_CODE_RE = /\A(IEV)?\s*(\d{2,3}-\d{2,3}-\d{2,3})\z/

    # Pattern matching an anchor's inner text that is just an IEV code
    # (not a meaningful term designation).
    IEV_CODE_TEXT_RE = /\A\s*IEV\s*\d{2,3}-\d{2,3}-\d{2,3}\s*\z/

    # SIMG/Figure patterns — custom IEV XML, pre-processed before Nokogiri.
    # Uses [^>] and [^<] instead of . to avoid polynomial backtracking.
    SIMG_PATH_REGEX = /<simg [^>]*\/\$file\/([\d\-\w.]+)>/
    FIGURE_ONE_REGEX = '<p><b>\\s*Figure\\s+(\\d)\\s+[–-]\\s+' \
                       '([^<]+)\\s*<\\/b>(<\\/p>)?'
    FIGURE_TWO_REGEX = "#{FIGURE_ONE_REGEX}\\s*#{FIGURE_ONE_REGEX}".freeze

    def parse_anchor_tag(text, term_domain)
      return nil if text.nil?
      return text unless text.include?("<")

      text = text.gsub(/\r\n?/, "\n")
      text = process_simg_figures(text, term_domain)
      text = fix_unquoted_href(text)

      # Second check: regex substitutions may have consumed all tags
      return text unless text.include?("<")

      doc = Nokogiri::HTML::DocumentFragment.parse(text)
      nodes_to_adoc(doc.children, term_domain)
    end

    def replace_newlines(input)
      input
        .gsub(/\r\n?/, "\n")
        .gsub('\n', "\n\n")
        .gsub(/<[pbr]+>/, "\n\n")
        .gsub(/<br\s*\/?>/, "\n\n")
        .gsub(/\s*\n[\n\s]+/, "\n\n")
        .strip
    end

    private

    # IEV data has unquoted href with spaces, e.g.
    #   <a href=IEV 102-01-10>...</a>
    # Nokogiri stops at first space, so add quotes.
    # Uses a specific IEV code pattern to avoid regex backtracking.
    def fix_unquoted_href(text)
      text.gsub(/href=(IEV\s\d{2,3}-\d{2,3}-\d{2,3})(?=[>\s])/) do
        "href=\"#{Regexp.last_match(1)}\""
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
      return reemit_element(node, inner) if TABLE_TAGS.include?(node.name)

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
      when "p"
        "#{inner}\n"
      when "div", "span"
        inner
      when "simg"
        inner.strip
      when "i"
        convert_italic(inner)
      when "sub"
        inner.empty? ? "" : "~#{inner}~"
      when "sup"
        inner.empty? ? "" : "^#{inner}^"
      when "ol", "ul"
        "\n\n#{convert_list(node, 1, term_domain)}\n\n"
      when "li"
        inner
      when "font"
        convert_font(node, inner)
      else
        node.to_s
      end
    end

    def convert_italic(text)
      case text.length
      when 0
        ""
      when 1..12
        "stem:[#{text}]"
      else
        "_#{text}_"
      end
    end

    # Renders a list as AsciiDoc. Each item is one list entry; a block
    # (<p>) after the item's first content is attached with a "+" list
    # continuation so formulas stay part of their item. Nested lists use
    # a deeper marker.
    def convert_list(node, depth, term_domain)
      unless node.element_children.any? { |child| child.name == "li" }
        return nodes_to_adoc(node.children, term_domain)
            .gsub(/^([*.]+)[ \t]*\n(?=stem:\[)/, '\\1 ')
      end

      marker = (node.name == "ol" ? "." : "*") * depth
      node.element_children.select { |c| c.name == "li" }.map do |item|
        "#{marker} #{list_item(item, depth, term_domain)}"
      end.join("\n")
    end

    def list_item(item, depth, term_domain)
      out = +""
      pending_break = false
      item.children.each do |child|
        pending_break = append_item_child(out, child, depth, term_domain,
                                          pending_break)
      end
      out.strip
    end

    def append_item_child(out, child, depth, term_domain, pending_break)
      if %w[ul ol].include?(child.name)
        out << "\n#{convert_list(child, depth + 1, term_domain)}\n"
        false
      else
        append_item_part(out, node_to_adoc(child, term_domain), pending_break,
                         child.name == "p")
      end
    end

    # Appends one rendered child to a list item and returns whether the
    # next content starts a new continuation block.
    def append_item_part(out, part, pending_break, block)
      if part.strip.empty?
        return append_item_whitespace(out, part, pending_break, block)
      end

      if (block || pending_break) && !out.strip.empty?
        out.rstrip!
        out << "\n+\n"
        part = part.lstrip
      end
      out << (block ? part.strip : part)
      block
    end

    def append_item_whitespace(out, part, pending_break, block)
      out << part unless out.empty? || pending_break || block
      pending_break
    end

    def reemit_element(node, inner)
      attrs = node.attribute_nodes.map do |a|
        %( #{a.name}="#{CGI.escapeHTML(a.value)}")
      end.join
      "<#{node.name}#{attrs}>#{inner}</#{node.name}>"
    end

    def convert_font(node, inner)
      style = node["style"].to_s
      style.include?("sans-serif") ? "`#{inner}`" : inner
    end

    def convert_link(node, inner)
      href = (node["href"] || "").to_s.strip

      if href.match?(IEV_CODE_RE)
        iev_code = href.sub(/\AIEV\s*/, "")
        display = render_term_for(inner, iev_code)
        "{{urn:iec:std:iec:60050-#{iev_code}, #{display}}}"
      elsif !href.empty?
        "#{href}[#{inner}]"
      else
        inner
      end
    end

    # Resolve the display (render) text for an IEV cross-reference.
    #
    # When the anchor text is already a meaningful term (e.g. "adjective"),
    # use it directly. When it's just a bare IEV code (e.g. "IEV 102-01-10"),
    # try to look up the actual term designation via DataSource.
    #
    # @param inner_text [String] the anchor element's inner text
    # @param iev_code [String] the extracted numeric IEV code (e.g. "102-01-10")
    # @return [String] the term designation to use as render text
    def render_term_for(inner_text, iev_code)
      stripped = inner_text.strip
      return stripped unless iev_code_only?(stripped)

      Iev.get(iev_code, "en") || stripped
    rescue StandardError
      stripped
    end

    # True when the anchor text is just a raw IEV code, not a term designation.
    def iev_code_only?(text)
      text.match?(IEV_CODE_TEXT_RE)
    end
  end
end
