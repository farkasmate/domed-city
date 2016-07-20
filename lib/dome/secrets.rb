module Dome
  class Secrets
    def initialize(environment)
      @environment = environment
      @settings    = Dome::Settings.new
      @hiera       = Dome::HieraLookups.new(@environment)
    end

    def secret_env_vars
      return if @settings.parse['dome'].nil? || @settings.parse['dome']['hiera_keys'].nil?
      @hiera.secret_env_vars(@settings.parse['dome']['hiera_keys'])
    end

    def extract_certs
      return if @settings.parse['dome'].nil? || @settings.parse['dome']['certs'].nil?
      @hiera.extract_certs(@settings.parse['dome']['certs'])
    end
  end
end
