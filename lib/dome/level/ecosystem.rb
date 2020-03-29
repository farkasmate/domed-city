# frozen_string_literal: true

require 'dome/level'

module Dome
  class EcosystemLevel < Level
    LEVEL_REGEX = %r{^terraform/(?<product>\w*)-(?<ecosystem>\w*)$}.freeze

    def state_bucket_name
      "itv-terraform-state-#{@project}-#{@ecosystem}"
    end
  end
end
