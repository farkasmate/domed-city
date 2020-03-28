# frozen_string_literal: true

module Dome
  module Helper
    module Level
      # FIXME: Remove dependency on *pwd* and reduce complexity
      # rubocop:disable Metrics/PerceivedComplexity
      def level
        directories = Dir.pwd.split('/')

        if directories[-1] == 'terraform'
          'product'
        elsif directories[-2] == 'terraform'
          'ecosystem'
        elsif directories[-3] == 'terraform'
          'environment'
        elsif directories[-4] == 'terraform' && directories[-1] == 'roles'
          'roles'
        elsif directories[-5] == 'terraform' && directories[-2] == 'services'
          'services'
        elsif directories[-5] == 'terraform' && directories[-2] == 'secrets' && directories[-1] == 'init'
          'secrets-init'
        elsif directories[-5] == 'terraform' && directories[-2] == 'secrets' && directories[-1] == 'config'
          'secrets-config'
        else
          Logger.error 'Invalid level: root'.colorize(:red)
          'root'
        end
      end
      # rubocop:enable Metrics/PerceivedComplexity
    end
  end
end
