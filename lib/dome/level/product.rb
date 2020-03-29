# frozen_string_literal: true

require 'dome/level'

module Dome
  class ProductLevel < Level
    LEVEL_REGEX = /^terraform$/.freeze

    def initialize(relative_path)
      # FIXME: Parse?
      @product = Dome::Settings['product']
      @ecosystem = 'prd'

      super
    end

    def state_bucket_name
      "itv-terraform-state-#{@project}"
    end
  end
end
