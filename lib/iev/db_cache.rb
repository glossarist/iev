# frozen_string_literal: true

require "fileutils"

module Iev
  class DbCache
    # @return [String]
    attr_reader :dir

    # @param dir [String] DB directory
    def initialize(dir)
      @dir = dir
      FileUtils.mkdir_p @dir
      file_version = "#{@dir}/version"
      File.exist? file_version or
        File.write file_version, VERSION, encoding: "utf-8"
    end

    # Save item
    # @param key [String]
    # @param value [String] Bibitem xml serialization
    def []=(key, value)
      return if value.nil?

      prefix_dir = "#{@dir}/#{prefix(key)}"
      FileUtils.mkdir_p prefix_dir
      File.write filename(key), value, encoding: "utf-8"
    end

    # Read item
    # @param key [String]
    # @return [String]
    def [](key)
      file = filename key
      return unless File.exist? file

      File.read(file, encoding: "utf-8")
    end

    # Return fetched date
    # @param key [String]
    # @return [String]
    def fetched(key)
      value = self[key]
      return unless value

      # if value =~ /^not_found/
      #   value.match(/\d{4}-\d{2}-\d{2}/).to_s
      # else
      doc = Nokogiri::XML value
      doc.at("/bibitem/fetched")&.text
      # end
    end

    # Returns all items
    # @return [Array<Hash>]
    def all
      Dir.glob("#{@dir}/**/*.xml").sort.map do |f|
        File.read(f, encoding: "utf-8")
      end
    end

    # Delete item
    # @param key [String]
    def delete(key)
      file = filename key
      File.delete file if File.exist? file
    end

    # Check if version of the DB match to the gem version.
    # @return [TrueClass, FalseClass]
    def check_version?
      v = File.read "#{@dir}/version", encoding: "utf-8"
      v == VERSION
    end

    # Set version of the DB to the gem version.
    # @return [Iev::DbCache]
    def set_version
      File.write "#{@dir}/version", VERSION, encoding: "utf-8"
      self
    end

    # if cached reference is undated, expire it after 60 days
    # @param key [String]
    # @param year [String]
    # def valid_entry?(key)
    #   datestr = fetched key
    #   return false unless datestr

    #   date = Date.parse datestr
    #   year || Date.today - date < 60
    # end

    private

    # Return item's file name
    # @param key [String]
    # @return [String]
    def filename(key)
      # prefcode = key.downcase.match /^(?<prefix>[^\(]+)\((?<code>[^\)]+)/
      # if prefcode
      #   "#{@dir}/#{prefcode[:prefix]}/#{prefcode[:code].gsub(/[-:\s\/]/, '_')}.xml"
      # else
      "#{@dir}/#{key.gsub(%r{[-:\s/]}, '_')}.xml"
      # end
    end

    # Return item's subdir
    # @param key [String]
    # @return [String]
    def prefix(key)
      # @registry.processors.detect do |_n, p|
      #   /^#{p.prefix}/.match(key) || processor.defaultprefix.match(key)
      # end[1].prefix.downcase
      key.downcase.match(/^[^(]+(?=\()/).to_s
    end
  end
end
