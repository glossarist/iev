require 'pstore'

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
      id = code + '/' + lang
      return bib_retval(new_bib_entry(code, lang)) if @db.nil?
      @db.transaction do
        # @db.delete(id) unless valid_bib_entry?(@db[id])
        @db[id] ||= new_bib_entry(code, lang)
        if @local_db.nil? then bib_retval(@db[id])
        else
          @local_db.transaction do
            @local_db[id] ||= @db[id]
            bib_retval(@local_db[id])
          end
        end
      end
    end

    def bib_retval(entry)
      # entry['term'] == 'not_found' ? '' : entry['term']
      entry['term']
    end

    # @return [Hash]
    def new_bib_entry(code, lang)
      term = Iev.get(code, lang)
      # term = 'not_found' if term.nil? || term.empty?
      { 'term' => term, 'definition' => nil }
    end

    # @param filename [String] DB filename
    # @param global [TrueClass, FalseClass]
    # @return [PStore]
    def open_cache_biblio(filename, global: true)
      return nil if filename.nil?
      db = PStore.new filename
      if File.exist? filename
        if global
          unless check_cache_version(db)
            File.delete filename
            warn 'Global cache version is obsolete and cleared.'
          end
          save_cache_version db
        elsif check_cache_version(db) then db
        else
          warn 'Local cache version is obsolete.'
          nil
        end
      else
        save_cache_version db
      end
    end

    def check_cache_version(cache_db)
      cache_db.transaction { cache_db[:version] == VERSION }
    end

    def save_cache_version(cache_db)
      unless File.exist? cache_db.path
        cache_db.transaction { cache_db[:version] = VERSION }
      end
      cache_db
    end
  end
end
