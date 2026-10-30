# frozen_string_literal: true

module Iev
  # Converts an HTML <table> element to an AsciiDoc table
  # (glossarist/iev-data#119).
  #
  # Colspan, rowspan and horizontal alignment are carried over. A table
  # that AsciiDoc cannot express faithfully (nested tables, lists inside
  # cells, a layout that is not a full grid) is not converted: #to_adoc
  # returns nil and the caller keeps the HTML markup.
  class TableConverter
    BLOCK_IN_CELL = %w[table ul ol].freeze
    ALIGNMENTS = { "left" => "<", "center" => "^", "right" => ">" }.freeze
    TEXT_ALIGN_RE = /text-align:\s*(left|center|right)/

    Cell = Struct.new(:node, :row, :col, :colspan, :rowspan)

    # @param table [Nokogiri::XML::Element] a <table> element
    # @yield [Nokogiri::XML::Node] renders the children of a cell or
    #   caption element to AsciiDoc text
    def initialize(table, &render)
      @table = table
      @render = render
    end

    # @return [String, nil] the AsciiDoc table, or nil when not representable
    def to_adoc
      return unless convertible?

      rows = row_nodes
      cells = layout(rows)
      return unless cells

      render_table(rows, cells)
    end

    private

    def convertible?
      @table.ancestors("table").empty? &&
        @table.css(BLOCK_IN_CELL.join(",")).empty? &&
        @table.element_children.all? { |c| section_or_row?(c) }
    end

    def section_or_row?(node)
      %w[caption colgroup col thead tbody tfoot tr].include?(node.name)
    end

    def row_nodes
      @table.xpath("./tr | ./thead/tr | ./tbody/tr | ./tfoot/tr").to_a
    end

    # Places every cell on the row/column grid. Returns nil unless the grid
    # is completely and unambiguously filled.
    def layout(rows)
      return if rows.empty?

      occupied = {}
      cells = []
      placed = rows.each_with_index.all? do |row, r|
        row_placed?(row, r, rows.size, occupied, cells)
      end
      cells if placed && full_grid?(occupied, rows.size)
    end

    def row_placed?(row, row_idx, row_count, occupied, cells)
      col = 0
      row.element_children.all? do |node|
        next false unless %w[td th].include?(node.name)

        col += 1 while occupied[[row_idx, col]]
        cell = build_cell(node, row_idx, col)
        next false unless fits?(cell, row_count, occupied)

        cells << cell
        col += cell.colspan
        true
      end
    end

    def build_cell(node, row_idx, col)
      Cell.new(node, row_idx, col, span(node["colspan"]),
               span(node["rowspan"]))
    end

    def span(value)
      number = value.to_i
      number.positive? ? number : 1
    end

    def fits?(cell, row_count, occupied)
      cell.row + cell.rowspan <= row_count && claimed?(cell, occupied)
    end

    def claimed?(cell, occupied)
      positions = positions_of(cell)
      return false if positions.any? { |pos| occupied[pos] }

      positions.each { |pos| occupied[pos] = true }
      true
    end

    def positions_of(cell)
      rows = cell.row...(cell.row + cell.rowspan)
      cols = cell.col...(cell.col + cell.colspan)
      rows.to_a.product(cols.to_a)
    end

    def full_grid?(occupied, row_count)
      columns = occupied.keys.map(&:last).max.to_i + 1
      (0...row_count).all? do |r|
        (0...columns).all? { |c| occupied[[r, c]] }
      end
    end

    def render_table(rows, cells)
      columns = cells.map { |c| c.col + c.colspan }.max
      lines = []
      caption = caption_text
      lines << ".#{caption}" if caption
      lines << "[#{attributes(rows, columns)}]"
      lines << "|==="
      lines.concat(row_lines(rows, cells))
      lines << "|==="
      "\n\n#{lines.join("\n")}\n\n"
    end

    def attributes(rows, columns)
      attrs = []
      attrs << "%header" if header_row?(rows.first)
      attrs << %(cols="#{columns}*")
      attrs.join(",")
    end

    def header_row?(row)
      row.element_children.all? { |c| c.name == "th" }
    end

    def row_lines(rows, cells)
      rows.each_index.flat_map do |r|
        row = cells.select { |c| c.row == r }
          .map { |c| "#{cell_prefix(c)}#{cell_text(c.node)}" }
        r.zero? ? row : ["", *row]
      end
    end

    def cell_prefix(cell)
      span = +""
      span << cell.colspan.to_s if cell.colspan > 1
      span << ".#{cell.rowspan}" if cell.rowspan > 1
      span << "+" unless span.empty?
      "#{span}#{alignment(cell.node)}|"
    end

    def alignment(node)
      name = node["align"].to_s.downcase
      name = node["style"].to_s[TEXT_ALIGN_RE, 1] if name.empty?
      ALIGNMENTS.fetch(name.to_s, "")
    end

    def cell_text(node)
      lines = @render.call(node).gsub(/\r\n?/, "\n").strip.split("\n", -1)
      single_blanks(lines.map(&:rstrip)).join("\n").gsub("|", "\\|")
    end

    # Collapses runs of blank lines to one.
    def single_blanks(lines)
      lines.each_with_object([]) do |line, out|
        out << line unless line.empty? && out.last&.empty?
      end
    end

    def caption_text
      node = @table.at_xpath("./caption")
      return unless node

      text = @render.call(node).gsub(/\s+/, " ").strip
      text.empty? ? nil : text
    end
  end
end
