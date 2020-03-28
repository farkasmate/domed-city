# frozen_string_literal: true

require 'dome/level'

module Dome
  class ProductLevel < Level
    def self.match(relative_path)
      /^terraform$/.match relative_path
    end
  end
end
