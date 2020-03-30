# frozen_string_literal: true

require 'dome/level'

module Dome
  class RolesLevel < Level
    LEVEL_REGEX = %r{^terraform/(?<product>\w*)-(?<ecosystem>\w*)/(?<environment>\w*)/roles$}.freeze

    def state_bucket_name
      "itv-terraform-state-#{@project}-#{@ecosystem}-#{@environment}-roles"
    end

    def validate
      validate_environment
      super
    end
  end
end
