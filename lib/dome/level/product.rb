# frozen_string_literal: true

require 'dome/level'

module Dome
  class ProductLevel < Level
    LEVEL_REGEX = /^terraform$/.freeze

    def initialize(relative_path)
      @account = "#{Dome::Settings['product']}-prd"

      super
    end
  end
end
