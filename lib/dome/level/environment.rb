# frozen_string_literal: true

require 'dome/level'

module Dome
  class EnvironmentLevel < Level
    LEVEL_REGEX = %r{^terraform/(?<product>\w*)-(?<ecosystem>\w*)/(?<environment>\w*)$}.freeze
  end
end
