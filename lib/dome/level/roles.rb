# frozen_string_literal: true

require 'dome/level'

module Dome
  class RolesLevel < Level
    LEVEL_REGEX = %r{^terraform/(?<product>\w*)-(?<ecosystem>\w*)/(?<environment>\w*)/roles$}.freeze
  end
end
