# frozen_string_literal: true

# (c) Copyright 2020 Ribose Inc.
#

module Iev
  module DataConversions
    refine String do
      def decode_html!
        replace(decode_html)
        nil
      end

      def decode_html
        HTMLEntities.new(:expanded).decode(self)
      end

      # Normalize various encoding anomalies like `\uFEFF` in strings
      def sanitize!
        unicode_normalize!
        delete!("\uFEFF")
        tr!("\u2011", "-")
        tr!("\u00a0", " ")
        gsub!(/[\u2000-\u2006]/, " ")
        strip!
        nil
      end

      # @see sanitize!
      def sanitize
        dup.tap(&:sanitize!)
      end

      def to_three_char_code
        Iev::Iso639Code.three_char_code(self).first
      end
    end
  end
end
