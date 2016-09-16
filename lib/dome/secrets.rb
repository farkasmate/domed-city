module Dome
  class Secrets
    attr_reader :settings, :hiera

    def initialize(environment)
      @environment = environment
      @settings    = Dome::Settings.new
      @hiera       = Dome::HieraLookup.new(@environment)
    end

    def secret_env_vars
      return if dome_config.nil? || hiera_keys_config.nil?
      @hiera.secret_env_vars(hiera_keys_config)
    end

    def extract_certs
      return if dome_config.nil? || certs_config.nil?
      @hiera.extract_certs(certs_config)
    end

    def dome_config
      puts "No #{'dome'.colorize(:green)} key found in your itv.yaml." unless @settings.parse['dome']
      @settings.parse['dome']
    end

    def hiera_keys_config
      puts "No #{'hiera_keys'.colorize(:green)} sub-key under #{'dome'.colorize(:green)} key found "\
      'in your itv.yaml.' unless @settings.parse['dome']['hiera_keys']
      @settings.parse['dome']['hiera_keys']
    end

    def certs_config
      puts "No #{'certs'.colorize(:green)} sub-key under #{'dome'.colorize(:green)} key found "\
      'in your itv.yaml.' unless @settings.parse['dome']['certs']
      @settings.parse['dome']['certs']
    end
  end
end
