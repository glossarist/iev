# frozen_string_literal: true

require "tmpdir"

module Iev
  class Config
    DEFAULT_REMOTE_BASE_URL = "https://raw.githubusercontent.com/glossarist/glossarist-data-iev/main/concepts"

    # Default mirror cache lives inside the repo's tmp/ directory (gitignored)
    # rather than Dir.tmpdir. macOS purges /var/folders/.../T/ aggressively —
    # a 19-hour mirror run lost 6,905 fetched pages to that cleanup.
    DEFAULT_PAGES_DIR = File.expand_path("../../tmp/pages", __dir__)

    attr_accessor :data_path, :cache_dir, :remote_base_url, :pages_dir

    def initialize
      @data_path = ENV.fetch("IEV_DATA_PATH", nil)
      @cache_dir = ENV["IEV_CACHE_DIR"] || File.join(Dir.tmpdir, "iev-cache")
      @remote_base_url = DEFAULT_REMOTE_BASE_URL
      @pages_dir = ENV["IEV_PAGES_DIR"] || DEFAULT_PAGES_DIR
    end
  end
end
