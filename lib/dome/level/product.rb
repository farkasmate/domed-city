# frozen_string_literal: true

require 'dome/level'

module Dome
  class ProductLevel < Level
    LEVEL_REGEX = /^terraform$/.freeze

    def initialize(relative_path)
      # FIXME: Move out of Level
      product = Dome::Settings.new.parse['product']

      @account = "#{product}-prd"

      super
    end
  end
end
