# (c) Copyright 2020 Ribose Inc.
#

module IEV
  module FixtureHelper
    def fixture_path(fixture_name)
      File.expand_path(fixture_name, fixture_root)
    end

    def fixture_root
      File.expand_path("../fixtures", __dir__)
    end
  end
end
