module Dome
  class Secrets
    def initialize(environment)
      @environment = environment
      @settings    = Dome::Settings.new
      @hiera       = Dome::HieraLookups.new(@environment)
    end

    def secret_env_vars
      return unless @settings.parse['dome']['hiera_keys'].nil?
      @hiera.secret_env_vars(@settings.parse['dome']['hiera_keys'])
    end

    def extract_certs
      return unless @settings.parse['dome']['certs'].nil?
      @hiera.extract_certs(@settings['dome']['certs'])
    end
  end
end
