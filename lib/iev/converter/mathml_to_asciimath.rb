# frozen_string_literal: true

module Iev
  module Converter
    class MathmlToAsciimath
      using DataConversions

      GREEK_ENTITIES = {
        "&alpha;" => "alpha",
        "&beta;" => "beta",
        "&gamma;" => "gamma",
        "&Gamma;" => "Gamma",
        "&delta;" => "delta",
        "&Delta;" => "Delta",
        "&epsilon;" => "epsilon",
        "&varepsilon;" => "varepsilon",
        "&zeta;" => "zeta",
        "&eta;" => "eta",
        "&theta;" => "theta",
        "&Theta;" => "Theta",
        "&vartheta;" => "vartheta",
        "&iota;" => "iota",
        "&kappa;" => "kappa",
        "&lambda;" => "lambda",
        "&Lambda;" => "Lambda",
        "&mu;" => "mu",
        "&nu;" => "nu",
        "&xi;" => "xi",
        "&Xi;" => "Xi",
        "&pi;" => "pi",
        "&Pi;" => "Pi",
        "&rho;" => "rho",
        "&sigma;" => "sigma",
        "&Sigma;" => "Sigma",
        "&tau;" => "tau",
        "&upsilon;" => "upsilon",
        "&phi;" => "phi",
        "&Phi;" => "Phi",
        "&varphi;" => "varphi",
        "&chi;" => "chi",
        "&psi;" => "psi",
        "&Psi;" => "Psi",
        "&omega;" => "omega",
      }.freeze

      class << self
        def convert(input)
          mathml_to_asciimath(input)
        end

        private

        def mathml_to_asciimath(input)
          return input unless input&.match?(/<|&/)

          return html_to_asciimath(input) unless input.include?("<math>")

          to_asciimath = Nokogiri::HTML.fragment(input, "UTF-8")

          to_asciimath.css("math").each do |math_element|
            asciimath = Plurimath::Math.parse(
              text_to_asciimath(math_element.to_xml), :mathml
            ).to_asciimath.strip

            if asciimath.empty?
              math_element.remove
            else
              math_element.replace "stem:[#{asciimath}]"
            end
          end

          html_to_asciimath(
            to_asciimath.children.to_s,
          )
        end

        def html_to_asciimath(input)
          return input if input.nil? || input.empty?

          to_asciimath = Nokogiri::HTML.fragment(input, "UTF-8")

          to_asciimath.css("i").each do |math_element|
            decoded = text_to_asciimath(math_element.text)
            case decoded.length
            when 1..12
              math_element.replace "stem:[#{decoded}]"
            when 0
              math_element.remove
            else
              math_element.replace "_#{decoded}_"
            end
          end

          to_asciimath.css("sub").each do |math_element|
            case math_element.text.length
            when 0
              math_element.remove
            else
              math_element.replace "~#{text_to_asciimath(math_element.text)}~"
            end
          end

          to_asciimath.css("sup").each do |math_element|
            case math_element.text.length
            when 0
              math_element.remove
            else
              math_element.replace "^#{text_to_asciimath(math_element.text)}^"
            end
          end

          to_asciimath.css("ol").each do |element|
            element.css("li").each do |li|
              li.replace ". #{li.text}"
            end
          end

          to_asciimath.css("ul").each do |element|
            element.css("li").each do |li|
              li.replace "* #{li.text}"
            end
          end

          to_asciimath.css('font[style*="sans-serif"]').each do |x|
            x.replace "`#{x.text}`"
          end

          html_entities_to_stem(
            to_asciimath
              .children.to_s
              .gsub("]stem:[", "")
              .gsub(%r{</?[uo]l>}, ""),
          )
        end

        def text_to_asciimath(text)
          html_entities_to_asciimath(text.decode_html)
        end

        def html_entities_to_asciimath(input)
          GREEK_ENTITIES.reduce(input) do |str, (entity, name)|
            str.gsub(entity, name)
          end
        end

        def html_entities_to_stem(input)
          GREEK_ENTITIES.reduce(input) do |str, (entity, name)|
            str.gsub(entity, "stem:[#{name}]")
          end
        end
      end
    end
  end
end
