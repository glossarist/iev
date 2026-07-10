# frozen_string_literal: true

module Iev
  module Reconciler
    # A collection of Change records for a single concept. Enumerable,
    # with query helpers for filtering by field or language.
    class ChangeSet
      include Enumerable

      attr_reader :code

      def initialize(code)
        @code = code
        @changes = []
      end

      def add(change)
        @changes << change
        self
      end

      def each(&block)
        @changes.each(&block)
      end

      def size
        @changes.size
      end

      def empty?
        @changes.empty?
      end

      def by_field(field)
        @changes.select { |c| c.field == field }
      end

      def by_language(lang)
        @changes.select { |c| c.language == lang }
      end

      # Hash of field => count, for summary statistics.
      def summary
        @changes.group_by(&:field).transform_values(&:size)
      end
    end
  end
end
