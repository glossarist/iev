# frozen_string_literal: true

module Iev
  module Fetcher
    # Source-of-truth collaborators for Mirror. Each Source responds to
    # `#fetch(url) -> html | nil` and `#quit`. Mirror accepts any Source
    # interchangeably; the choice of source does not affect caching,
    # parsing, or output.
    module Source
      autoload :Archive, "iev/fetcher/source/archive"
    end
  end
end
