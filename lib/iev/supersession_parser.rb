# frozen_string_literal: true

# (c) Copyright 2020 Ribose Inc.
#

require "English"
module Iev
  # Parses information from the spreadsheet's REPLACES column.
  #
  # @example
  #   SupersessionParser.new(cell_data_string).supersessions
  class SupersessionParser
    include Cli::Ui
    using DataConversions

    attr_reader :raw_str, :src_str, :supersessions

    # Regular expression which describes IEV relation, for example
    # +881-01-23:1983-01+ or +845-03-55:1987+.
    IEV_SUPERSESSION_RX = /
      \A
      (?:IEV\s+)? # some are prefixed with IEV, it is unnecessary though
      (?<ref>\d{3}-\d{2}-\d{2})
      \s* # some have whitespaces around the separator
      : # separator
      \s* # some have whitespaces around the separator
      (?<version>[-0-9]+)
      \Z
    /x

    def initialize(source_str)
      @raw_str = source_str.dup.freeze
      @src_str = raw_str.sanitize.freeze
      @supersessions = parse
    end

    private

    def parse
      return if empty_source?

      if IEV_SUPERSESSION_RX =~ src_str
        [relation_from_match($LAST_MATCH_INFO)]
      else
        warn "Incorrect supersession: '#{src_str}'"
        nil
      end
    end

    def empty_source?
      /\w/ !~ src_str
    end

    def relation_from_match(match_data)
      {
        "type" => "supersedes",
        "ref" => iev_ref_from_match(match_data),
      }
    end

    def iev_ref_from_match(match_data)
      {
        "source" => "IEV",
        "id" => match_data[:ref],
        "version" => match_data[:version],
      }
    end
  end
end
