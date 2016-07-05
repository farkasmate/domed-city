module Dome
  class HieraLookups
    def initialize(environment)
      @environment  = environment.environment
      @account      = environment.account
      @settings     = Dome::Settings.new
    end

    def config
      puppet_dir  = File.join(@settings.project_root, 'puppet')
      config      = YAML.load_file(File.join(puppet_dir, 'hiera.yaml'))
      private_key = "#{puppet_dir}/keys/private_key.pkcs7.pem"
      public_key  = "#{puppet_dir}/keys/public_key.pkcs7.pem"

      unless File.exists?(private_key) and File.exists?(public_key)
        raise "Cannot find eyaml keys! make sure they exist at #{public_key} and #{private_key}"
      end

      config[:logger] = 'noop'
      config[:yaml][:datadir] = "#{puppet_dir}/hieradata"
      config[:eyaml][:datadir] = "#{puppet_dir}/hieradata"
      config[:eyaml][:pkcs7_private_key] = private_key
      config[:eyaml][:pkcs7_public_key] = public_key

      config
    end

    def lookup(key, default = nil, order_override = nil, resolution_type = :priority)
      hiera = Hiera.new(config: config)

      hiera_scope = {}
      hiera_scope['ecosystem']  = @account
      hiera_scope['location']   = 'awseuwest1'
      hiera_scope['env']        = @environment

      hiera.lookup(key.to_s, default, hiera_scope, order_override, resolution_type)
    end

    def secret_env_vars(secret_vars = {})
      secret_vars.each_pair do |key, val|
        ENV["TF_VAR_#{key}"] = lookup(val)
      end
    end

    def extract_certs(certs = {})
      cert_dir = "#{@settings.project_root}/terraform/certs"
      FileUtils.mkdir_p cert_dir

      certs.each_pair do |key, val|
        File.open("#{cert_dir}/#{key}", 'w') { |f| f.write(hiera_lookup(val)) }
      end
    end
  end
end
