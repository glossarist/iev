# frozen_string_literal: true

# (c) Copyright 2020 Ribose Inc.
#

module Iev
  module Cli
    def self.start(arguments)
      Signal.trap("INT") do
        Ui.info "Signal SIGINT received, quitting!"
        Kernel.exit(1)
      end

      Signal.trap("TERM") do
        Ui.info "Signal SIGTERM received, quitting!"
        Kernel.exit(1)
      end

      Iev::Cli::Command.start(arguments)
    end
  end
end
