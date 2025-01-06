# frozen_string_literal: true

# (c) Copyright 2020 Ribose Inc.
#

# rubocop:todo Style/RedundantRegexpEscape

require "English"
module Iev
  # Parses information from the spreadsheet's SOURCE column.
  #
  # @example
  #   SourceParser.new(cell_data_string).parsed_sources
  class SourceParser
    include Cli::Ui
    include Utilities
    using DataConversions

    attr_reader :src_split, :parsed_sources, :raw_str, :src_str

    def initialize(source_str, term_domain)
      @raw_str = source_str.dup.freeze
      @src_str = raw_str.decode_html.sanitize.freeze
      @term_domain = term_domain
      parse
    end

    private

    def parse
      @src_split = split_source_field(src_str)
      @parsed_sources = src_split.map { |src| extract_single_source(src) }
    end

    def split_source_field(source)
      # TODO: Calling String#gsub with a single hash argument would be probably
      # better than calling that method multiple times.  But change is
      # not necessarily that easy to do.

      # IEC 62047-22:2014, 3.1.1, modified – In the definition, ...
      source = source
        .gsub(/;\s?([A-Z][A-Z])/, ';; \1')
        .gsub(/MOD[,\.]/, "MOD;;")

      # 702-01-02 MOD,ITU-R Rec. 431 MOD
      # 161-06-01 MOD. ITU RR 139 MOD
      source = source
        .gsub(/MOD,\s*([UIC\d])/, 'MOD;; \1')
        .gsub(/MOD[,\.]/, "MOD;;")

      # 702-09-44 MOD, 723-07-47, voir 723-10-91
      source = source
        .gsub(/MOD,\s*(\d{3})/, 'MOD;; \1')
        .gsub(/,\s*see\s*(\d{3})/, ';;see \1')
        .gsub(/,\s*voir\s*(\d{3})/, ';;voir \1')

      # IEC 62303:2008, 3.1, modified and IEC 62302:2007, 3.2; IAEA 4
      # CEI 62303:2008, 3.1, modifiée et CEI 62302:2007, 3.2; AIEA 4
      source = source
        .gsub(/modified and ([ISOECUT])/, 'modified;; \1')
        .gsub(/modifiée et ([ISOECUT])/, 'modifiée;; \1')

      # 725-12-50, ITU RR 11
      source = source.gsub(/,\s+ITU/, ";; ITU")

      # 705-02-01, 702-02-07
      source = source.gsub(
        /(\d{2,3}-\d{2,3}-\d{2,3}),\s*(\d{2,3}-\d{2,3}-\d{2,3})/, '\1;; \2'
      )

      source.split(";;").map(&:strip)
    end

    def extract_single_source(raw_ref)
      relation_type = extract_source_relationship(raw_ref)
      clean_ref = normalize_ref_string(raw_ref)
      source_ref = extract_source_ref(clean_ref)
      clause = extract_source_clause(clean_ref)

      {
        "ref" => source_ref,
        "clause" => clause,
        "link" => obtain_source_link(source_ref),
        "relationship" => relation_type,
        "original" => Iev::Converter.mathml_to_asciimath(
          parse_anchor_tag(raw_ref, @term_domain),
        ),
      }.compact
    rescue ::RelatonBib::RequestError => e
      warn e.message
    end

    def normalize_ref_string(str)
      # définition 3.60 de la 62127-1
      # definition 3.60 of 62127-1
      # définition 3.60 de la 62127-1
      # definition 3.7 of IEC 62127-1 MOD, adapted from 4.2.9 of IEC 61828 and 3.6 of IEC 61102
      # définition 3.7 de la CEI 62127-1 MOD, adaptées sur la base du 4.2.9 de la CEI 61828 et du 3.6 de la CEI 61102
      # definition 3.54 of 62127-1 MOD
      # définition 3.54 de la CEI 62127-1 MOD
      # IEC 62313:2009, 3.6, modified
      # IEC 62313:2009, 3.6, modifié

      str
        .gsub(/CEI/, "IEC")
        .gsub(/Guide IEC/, "IEC Guide")
        .gsub(%r{Guide ISO/IEC}, "ISO/IEC Guide")
        .gsub(/VEI/, "IEV")
        .gsub(/UIT/, "ITU")
        .gsub(/IUT-R/, "ITU-R")
        .gsub(/UTI-R/, "ITU-R")
        .gsub(/Recomm[ea]ndation ITU-T/, "ITU-T Recommendation")
        .gsub(/ITU-T (\w.\d{3}):(\d{4})/, 'ITU-T Recommendation \1 (\2)')
        .gsub(/ITU-R Rec. (\d+)/, 'ITU-R Recommendation \1')
        .gsub(/[≈≠]\s+/, "")
        .sub(/ИЗМ\Z/, "MOD")
        .sub(/definition ([\d\.]+) of ([\d\-\:]+) MOD/, 'IEC \2, \1, modified - ')
        .sub(/definition ([\d\.]+) of IEC ([\d\-\:]+) MOD/, 'IEC \2, \1, modified - ')
        .sub(/définition ([\d\.]+) de la ([\d\-\:]+) MOD/, 'IEC \2, \1, modified - ')
        .sub(/définition ([\d\.]+) de la IEC ([\d\-\:]+) MOD/, 'IEC \2, \1, modified - ')
        .sub(/(\d{3})\ (\d{2})\ (\d{2})/, '\1-\2-\3') # for 221 04 03

      # .sub(/\A(from|d'après|voir la|see|See|voir|Voir)\s+/, "")
    end

    def extract_source_ref(str)
      match_source_ref_string(str)
        .sub(/, modifi(ed|é)\Z/, "")
        .strip
    end

    def match_source_ref_string(str)
      case str
      when /SI Brochure/, /Brochure sur le SI/
        # SI Brochure, 9th edition, 2019, 2.3.1
        # SI Brochure, 9th edition, 2019, Appendix 1
        # Brochure sur le SI, 9<sup>e</sup> édition, 2019, Annexe 1
        "BBIPM SI Brochure TEMP DISABLED DUE TO RELATON"

      when /VIM/
        "JCGM VIM"
      # IEC 60050-121, 151-12-05
      when /IEC 60050-(\d+), (\d{2,3}-\d{2,3}-\d{2,3})/
        "IEC 60050-#{::Regexp.last_match(1)}"
      when /IEC 60050-(\d+):(\d+), (\d{2,3}-\d{2,3}-\d{2,3})/
        "IEC 60050-#{::Regexp.last_match(1)}:#{::Regexp.last_match(2)}"
      when /(AIEA|IAEA) (\d+)/
        "IAEA #{::Regexp.last_match(2)}"
      when /IEC\sIEEE ([\d\:\-]+)/
        "IEC/IEEE #{::Regexp.last_match(1)}".sub(/:\Z/, "")
      when /CISPR ([\d\:\-]+)/
        "IEC CISPR #{::Regexp.last_match(1)}"
      when /RR (\d+)/
        "ITU-R RR"
      # IEC 50(845)
      when /IEC (\d+)\((\d+)\)/
        "IEC 600#{::Regexp.last_match(1)}-#{::Regexp.last_match(1)}"
      when %r{(ISO|IEC)[/\ ](PAS|TR|TS) ([\d\:\-]+)}
        "#{::Regexp.last_match(1)}/#{::Regexp.last_match(2)} #{::Regexp.last_match(3)}".sub(
          /:\Z/, ""
        )
      when %r{ISO/IEC ([\d\:\-]+)}
        "ISO/IEC #{::Regexp.last_match(1)}".sub(/:\Z/, "")
      when %r{ISO/IEC/IEEE ([\d\:\-]+)}
        "ISO/IEC/IEEE #{::Regexp.last_match(1)}".sub(/:\Z/, "")

      # ISO 140/4
      when %r{ISO (\d+)/(\d+)}
        "ISO #{::Regexp.last_match(1)}-#{::Regexp.last_match(2)}"
      when /Norme ISO (\d+)-(\d+)/
        "ISO #{::Regexp.last_match(1)}:#{::Regexp.last_match(2)}"
      when %r{ISO/IEC Guide ([\d\:\-]+)}i
        "ISO/IEC Guide #{::Regexp.last_match(1)}".sub(/:\Z/, "")
      when /(ISO|IEC) Guide ([\d\:\-]+)/i
        "#{::Regexp.last_match(1)} Guide #{::Regexp.last_match(2)}".sub(/:\Z/,
                                                                        "")

      # ITU-T Recommendation F.791 (11/2015)
      when %r{ITU-T Recommendation (\w.\d+) \((\d+/\d+)\)}i
        "ITU-T Recommendation #{::Regexp.last_match(1)} (#{::Regexp.last_match(2)})"

      # ITU-T Recommendation F.791:2015
      when /ITU-T Recommendation (\w.\d+):(\d+)/i
        "ITU-T Recommendation #{::Regexp.last_match(1)} (#{::Regexp.last_match(2)})"

      when /ITU-T Recommendation (\w\.\d+)/i
        "ITU-T Recommendation #{::Regexp.last_match(1)}"

      # ITU-R Recommendation 592 MOD
      when /ITU-R Recommendation (\d+)/i
        "ITU-R Recommendation #{::Regexp.last_match(1)}"
      # ISO 669: 2000 3.1.16
      when /ISO ([\d\-]+:\s?\d{4})/
        "ISO #{::Regexp.last_match(1)}".sub(/:\Z/, "")
      when /ISO ([\d\:\-]+)/
        "ISO #{::Regexp.last_match(1)}".sub(/:\Z/, "")
      when /IEC ([\d\:\-]+)/
        "IEC #{::Regexp.last_match(1)}".sub(/:\Z/, "")
      when /definition (\d\.[\d\.]+) of ([\d\-]*)/,
        /définition (\d\.[\d\.]+) de la ([\d\-]*)/
        "IEC #{::Regexp.last_match(2)}".sub(/:\Z/, "")

      when /IEV (\d{2,3}-\d{2,3}-\d{2,3})/, /(\d{2,3}-\d{2,3}-\d{2,3})/
        "IEV"
      when /IEV part\s+(\d+)/, /partie\s+(\d+)\s+de l'IEV/
        "IEC 60050-#{::Regexp.last_match(1)}"

      when /International Telecommunication Union (ITU) Constitution/,
        /Constitution de l’Union internationale des télécommunications (UIT)/
        "International Telecommunication Union (ITU) Constitution (Ed. 2015)"
      else
        debug :sources, "Failed to parse source: '#{str}'"
        str
      end
    end

    def extract_source_clause(str)
      # Strip out the modifications
      str = str.sub(/[,\ ]*modif.+\s[-–].*\Z/, "")

      # Strip these:
      # see figure 466-6
      # voir fig. 4.9
      str = str.gsub(/\A(see|voir) fig. [\d\.]+/, "")
      str = str.gsub(/\A(see|voir) figure [\d\.]+/, "")

      # str = 'ITU-T Recommendation F.791:2015, 3.14,'
      results = [
        [/RR (\d+)/, "1"],
        [/VIM (.+)/, "1"],
        [/item (\d\.[\d\.]+)/, "1"],
        [/d[eé]finition (\d[\d\.]+)/, "1"],
        [/figure ([\d\.\-]+)/, "figure 1"],
        [/fig\. ([\d\.\-]+)/, "figure 1"],
        [/IEV (\d{2,3}-\d{2,3}-\d{2,3})/, "1"],
        [/(\d{2,3}-\d{2,3}-\d{2,3})/, "1"],

        # 221 04 03
        [/(\d{3}\ \d{2}\ \d{2})/, "1"],
        # ", 1.1"

        # "SI Brochure, 9th edition, 2019, 2.3.1,"
        [/,\s?(\d+\.[\d\.]+)/, "1"],
        #  SI Brochure, 9th edition, 2019, Appendix 1, modified
        #  Brochure sur le SI, 9<sup>e</sup> édition, 2019, Annexe 1,
        [/\d{4}, (Appendix \d)/, "1"],
        [/\d{4}, (Annexe \d)/, "1"],

        # International Telecommunication Union (ITU) Constitution (Ed. 2015), No. 1012 of the Annex,
        # Constitution de l’Union internationale des télécommunications (UIT) (Ed. 2015), N° 1012 de l’Annexe,
        [/, (No. \d{4} of the Annex)/, "1"],
        [/, (N° \d{4} 1012 de l’Annexe)/, "1"],

        # ISO/IEC 2382:2015 (https://www.iso.org/obp/ui/#iso:std:iso-iec:2382:ed-1:v1:en), 2126371
        [/\), (\d{7}),/, "1"],

        # " 1.1 "
        [/\s(\d+\.[\d\.]+)\s?/, "1"],
        # "ISO/IEC Guide 2 (14.1)"
        [/\((\d+\.[\d\.]+)\)/, "1"],

        # "ISO/IEC Guide 2 (14.5 MOD)"
        [/\((\d+\.[\d\.]+)\ MOD\)/, "1"],

        # ISO 80000-10:2009, item 10-2.b,
        # ISO 80000-10:2009, point 10-2.b,

        [/\AISO 80000-10:2009, (item [\d\.\-]+\w?)/, "1"],
        [/\AISO 80000-10:2009, (point [\d\.\-]+\w?)/, "1"],

        # IEC 80000-13:2008, 13-9,
        [/\AIEC 80000-13:2008, ([\d\.\-]+\w?),/, "1"],
        [/\AIEC 80000-13:2008, ([\d\.\-]+\w?)\Z/, "1"],

        # ISO 921:1997, definition 6,
        # ISO 921:1997, définition 6,
        [/\AISO [\d:]+, (d[ée]finition \d+)/, "1"],

        # "ISO/IEC/IEEE 24765:2010,  <i>Systems and software engineering – Vocabulary</i>, 3.234 (2)
        [/, ([\d\.\w]+ \(\d+\))/, "1"],
      ].map do |regex, _rule|
        # TODO: Rubocop complains about unused rule -- need to make sure
        # that no one forgot about something.
        res = []
        # puts "str is '#{str}'"
        # puts "regex is '#{regex.to_s}'"
        str.scan(regex).each do |result|
          # puts "result is #{result.first}"
          res << {
            index: $LAST_MATCH_INFO.offset(0)[0],
            clause: result.first.strip,
          }
        end
        res
        # sort by index and also the length of match
      end.flatten.sort_by { |hash| [hash[:index], -hash[:clause].length] }

      # pp results

      results.dig(0, :clause)
    end

    def extract_source_relationship(str)
      type = case str
             when /≠/
               :not_equal
             when /≈/
               :similar
             when /^([Ss]ee)|([Vv]oir)/
               :related
             when /MOD/, /ИЗМ/
               :modified
             when /modified/, /modifié/
               :modified
             when /^(from|d'après)/,
        /^(definition (.+) of)|(définition (.+) de la)/
               :identical
             else
               :identical
             end

      case str
      when /^MOD ([\d\-])/
        {
          "type" => type.to_s,
        }
      when /(modified|modifié|modifiée|modifiés|MOD)\s*[–-]?\s+(.+)\Z/
        {
          "type" => type.to_s,
          "modification" => Iev::Converter.mathml_to_asciimath(
            parse_anchor_tag(::Regexp.last_match(2), @term_domain),
          ).strip,
        }
      else
        {
          "type" => type.to_s,
        }
      end
    end

    # Uses Relaton to obtain link for given source ref.
    def obtain_source_link(ref)
      RelatonDb.instance.fetch(ref)&.url
    end
  end
end

# rubocop:enable Style/RedundantRegexpEscape
