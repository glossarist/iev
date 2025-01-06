# frozen_string_literal: true

# (c) Copyright 2020 Ribose Inc.
#

module Iev
  module ConsoleHelper
    # Executes given block.  Anything written to $stdout or $stderr in that
    # block is captured and returned.
    #
    # @return Array - a three-element array composed of captured stdout,
    #   captured stderr, and block's return value
    def capture_output_streams
      original_stdout = $stdout
      original_stderr = $stderr
      $stdout = fake_stdout = StringIO.new
      $stderr = fake_stderr = StringIO.new

      begin
        block_return_value = yield
        [fake_stdout.string, fake_stderr.string, block_return_value]
      ensure
        $stdout = original_stdout
        $stderr = original_stderr
      end
    end

    # Executes given block.  Anything written to $stdout or $stderr in that
    # block is suppressed.
    #
    # @return Object - block's return value
    def silence_output_streams(&)
      error = capture_output_streams(&)[2]

      raise ::StandardError, error if error
    end
  end
end
