# frozen_string_literal: true

# (c) Copyright 2020 Ribose Inc.
#

require "singleton"

module Iev
  # Relaton cach singleton.
  class RelatonDb
    include Singleton
    include Cli::Ui

    def initialize
      info "Initializing Relaton..."
      @db = Relaton::Db.new "db", nil
    end

    # @param code [String] reference
    # @return [RelatonIso::IsoBibliongraphicItem]
    def fetch(code)
      retrying_on_failures do
        capture_output_streams do
          @db.fetch code
        end
      end
    end

    private

    def retrying_on_failures(attempts: 4)
      curr_attempt = 1

      begin
        yield
      rescue StandardError
        raise unless curr_attempt <= attempts

        sleep(2**curr_attempt * 0.1)
        curr_attempt += 1
        retry
      end
    end

    def capture_output_streams
      original_stdout = $stdout
      original_stderr = $stderr
      $stderr = $stdout = fake_out = StringIO.new

      begin
        yield
      ensure
        $stdout = original_stdout
        $stderr = original_stderr
        debug(:relaton, fake_out.string) if fake_out.pos.positive?
      end
    end
  end
end
