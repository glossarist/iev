# frozen_string_literal: true

# require 'pstore'
require_relative "db_cache"

module Iev
  # Cache class.
  class Db
    # @param global_cache [String] filename of global DB
    # @param local_cache [String] filename of local DB
    def initialize(global_cache, local_cache)
      @db = open_cache_biblio(global_cache)
      @local_db = open_cache_biblio(local_cache, global: false)
      @db_name = global_cache
      @local_db_name = local_cache
    end

    # @param [String] code for example "103-01-02"
    # @param [String] lang language code, for examle "en"
    # @return [String] Relaton XML serialisation of reference
    def fetch(code, lang)
      check_bibliocache(code, lang)
    end

    private

    def check_bibliocache(code, lang)
      id = "#{code}/#{lang}"
      return bib_retval(new_bib_entry(code, lang)) if @db.nil?

      # @db.delete(id) unless valid_bib_entry?(@db[id])
      @db[id] ||= new_bib_entry(code, lang)
      if @local_db.nil? then bib_retval(@db[id])
      else
        @local_db[id] ||= @db[id]
        bib_retval(@local_db[id])
      end
    end

    def bib_retval(entry)
      # entry['term'] == 'not_found' ? '' : entry['term']
      # entry["term"]
      /^not_found/.match?(entry) ? nil : entry
    end

    # @return [Hash]
    def new_bib_entry(code, lang)
      Iev.get(code, lang)
    end

    # @param dir [String] DB dir
    # @param global [TrueClass, FalseClass]
    # @return [Iev::DbCache, nil]
    def open_cache_biblio(dir, global: true)
      return nil if dir.nil?

      db = DbCache.new dir
      if global
        unless db.check_version?
          FileUtils.rm_rf(Dir.glob(File.join(dir, "*")), secure: true)
          warn "Global cache version is obsolete and cleared."
        end
        db.set_version
      elsif db.check_version? then db
      else
        warn "Local cache version is obsolete."
        nil
      end
    end

    # def check_cache_version(cache_db)
    #   cache_db.transaction { cache_db[:version] == VERSION }
    # end

    # def save_cache_version(cache_db)
    #   unless File.exist? cache_db.path
    #     cache_db.transaction { cache_db[:version] = VERSION }
    #   end
    #   cache_db
    # end
  end
end
