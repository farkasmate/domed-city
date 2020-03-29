# frozen_string_literal: true

require 'dome/level'

module Dome
  class EnvironmentLevel < Level
    LEVEL_REGEX = %r{^terraform/(?<product>\w*)-(?<ecosystem>\w*)/(?<environment>\w*)$}.freeze

    def state_bucket_name
      "itv-terraform-state-#{@project}-#{@ecosystem}-#{@environment}"
    end

    # FIXME: Do we need this?
    def plan_file
      "plans/#{@account}-#{@environment}-plan.tf"
    end
  end
end
