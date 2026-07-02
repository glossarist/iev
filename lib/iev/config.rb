# frozen_string_literal: true

require "tmpdir"

module Iev
  class Config
    DEFAULT_REMOTE_BASE_URL = "https://raw.githubusercontent.com/glossarist/glossarist-data-iev/main/concepts"

    # Default mirror cache lives OUTSIDE the repo, at <repo-parent>/iev-data-latest,
    # which is itself a private git repo (glossarist/iev-data-latest) so the
    # raw HTML snapshots are versioned and shareable. This keeps the cache
    # outside repo operations (rm -rf, branch switches), persists across
    # reboots (so Dir.tmpdir is wrong — macOS purges it), and survives
    # accidental deletion of the iev working tree.
    DEFAULT_PAGES_DIR = File.expand_path("../../../iev-data-latest", __dir__)

    attr_accessor :data_path, :cache_dir, :remote_base_url, :pages_dir

    def initialize
      @data_path = ENV.fetch("IEV_DATA_PATH", nil)
      @cache_dir = ENV["IEV_CACHE_DIR"] || File.join(Dir.tmpdir, "iev-cache")
      @remote_base_url = DEFAULT_REMOTE_BASE_URL
      @pages_dir = ENV["IEV_PAGES_DIR"] || DEFAULT_PAGES_DIR
    end
  end
end
