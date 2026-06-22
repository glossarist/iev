# frozen_string_literal: true

require "json"
require "digest"
require "time"
require "pathname"

module Iev
  module Fetcher
    # File-based raw-HTML cache for the Fetcher pipeline. Stores section
    # browse pages under +sections/+ and concept pages under +pages/+,
    # alongside a JSON manifest that records sha256, fetched_at, and status
    # for every code.
    #
    # The filesystem + manifest together are the source of truth for
    # resumability: a code whose HTML file is present and whose manifest
    # status is +:ok+ is skipped on subsequent runs.
    class PageStore
      STATUSES = %i[ok not_found waf_blocked].freeze

      SECTION_DIR = "sections"
      PAGES_DIR = "pages"
      MANIFEST_FILE = "manifest.json"

      # One manifest record per code.
      Entry = Struct.new(:sha256, :fetched_at, :status, keyword_init: true) do
        def to_h
          { "sha256" => sha256, "fetched_at" => fetched_at,
            "status" => status.to_s }
        end

        def self.from_hash(hash)
          new(sha256: hash["sha256"],
              fetched_at: hash["fetched_at"],
              status: hash["status"].to_sym)
        end
      end

      # @param root_dir [String, Pathname] defaults to Iev.config.pages_dir.
      def initialize(root_dir: Iev.config.pages_dir)
        @root_dir = Pathname.new(root_dir)
      end

      attr_reader :root_dir

      # --- concept pages ---

      def put_concept(code, html, status: :ok)
        write(:pages, code, html, status)
      end

      def get_concept(code) = read(:pages, code)

      def concept_cached?(code) = file?(:pages, code)

      # --- section pages ---

      def put_section(code, html, status: :ok)
        write(:sections, code, html, status)
      end

      def get_section(code) = read(:sections, code)

      def section_cached?(code) = file?(:sections, code)

      # --- status queries (manifest-driven) ---

      # @return [Symbol] one of +:ok+, +:not_found+, +:waf_blocked+, +:missing+.
      def status(code)
        manifest[code.to_s]&.status&.to_sym || :missing
      end

      # Record a failure without writing an HTML file.
      def mark_failed(code, status:)
        update_manifest(code, html: nil, status: status)
      end

      # --- iteration ---

      # Yields [code, html] for every cached concept page whose code is in
      # +scope+. Returns an Enumerator when called without a block.
      #
      # @param scope [Scope, nil] defaults to +Scope.all+.
      def each_concept(scope: nil, &block)
        scope ||= Scope.all
        return enum_for(:each_concept, scope: scope) unless block

        each_concept_path do |code, html|
          yield code, html if scope.includes?(code)
        end
      end

      # Flush the in-memory manifest to disk.
      def save_manifest = write_manifest

      private

      def write(kind, code, html, status)
        path = path_for(kind, code)
        path.dirname.mkpath
        path.write(html, encoding: "utf-8")
        update_manifest(code, html: html, status: status)
      end

      def read(kind, code)
        path = path_for(kind, code)
        path.exist? ? path.read(encoding: "utf-8") : nil
      end

      def file?(kind, code)
        path_for(kind, code).exist?
      end

      def path_for(kind, code)
        sub = kind == :sections ? SECTION_DIR : PAGES_DIR
        @root_dir.join(sub, "#{code}.html")
      end

      def update_manifest(code, html:, status:)
        manifest[code.to_s] = Entry.new(
          sha256: html && Digest::SHA256.hexdigest(html),
          fetched_at: Time.now.utc.iso8601,
          status: status,
        )
        write_manifest
      end

      def write_manifest
        @root_dir.mkpath
        manifest_path.write(JSON.pretty_generate(manifest_for_json),
                            encoding: "utf-8")
      end

      def manifest_path
        @root_dir.join(MANIFEST_FILE)
      end

      def manifest
        @manifest ||= load_manifest
      end

      def load_manifest
        path = manifest_path
        return {} unless path.exist?

        JSON.parse(path.read(encoding: "utf-8"))
          .transform_values { |hash| Entry.from_hash(hash) }
      end

      def manifest_for_json
        manifest.transform_values(&:to_h)
      end

      def each_concept_path
        glob = @root_dir.join(PAGES_DIR, "*.html")
        Dir.glob(glob).each do |path|
          code = File.basename(path, ".html")
          yield code, File.read(path, encoding: "utf-8")
        end
      end
    end
  end
end
