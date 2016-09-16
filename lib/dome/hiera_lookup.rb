module Dome
  class HieraLookup
    def initialize(environment)
      @environment = environment.environment
      @account     = environment.account
      @ecosystem   = environment.ecosystem
      @settings    = Dome::Settings.new
    end

    def config
      config = YAML.load_file(File.join(puppet_dir, 'hiera.yaml'))
      config[:logger] = 'noop'
      config[:yaml][:datadir] = "#{puppet_dir}/hieradata"
      config[:eyaml][:datadir] = "#{puppet_dir}/hieradata"
      config[:eyaml][:pkcs7_private_key] = eyaml_private_key
      config[:eyaml][:pkcs7_public_key] = eyaml_public_key
      config
    end

    def puppet_dir
      File.join(@settings.project_root, 'puppet')
    end

    def eyaml_private_key
      private_key = File.join(puppet_dir, 'keys/private_key.pkcs7.pem')
      raise "Cannot find eyaml private key! Make sure it exists at #{private_key}" unless File.exist?(private_key)
      private_key
    end

    def eyaml_public_key
      public_key = File.join(puppet_dir, 'keys/public_key.pkcs7.pem')
      raise "Cannot find eyaml public key! Make sure it exists at #{public_key}" unless File.exist?(public_key)
      public_key
    end

    def lookup(key, default = nil, order_override = nil, resolution_type = :priority)
      hiera = Hiera.new(config: config)

      hiera_scope = {}
      hiera_scope['ecosystem'] = @ecosystem
      hiera_scope['location']  = 'aeuw1'
      hiera_scope['env']       = @environment

      hiera.lookup(key.to_s, default, hiera_scope, order_override, resolution_type)
    end

    def secret_env_vars(secret_vars)
      secret_vars.each_pair do |key, val|
        hiera_lookup = lookup(val)
        terraform_env_var = "TF_VAR_#{key}"
        ENV[terraform_env_var] = hiera_lookup
        if hiera_lookup
          puts "Setting #{terraform_env_var.colorize(:green)}."
        else
          puts "Hiera lookup failed for '#{val}', so #{terraform_env_var} was not set.".colorize(:red)
        end
      end
    end

    def extract_certs(certs)
      create_certificate_directory

      certs.each_pair do |key, val|
        directory = "#{certificate_directory}/#{key}"
        puts "Extracting cert #{key.colorize(:green)} into: #{directory.colorize(:green)}"
        File.open(directory, 'w') { |f| f.write(lookup(val)) }
      end
    end

    def create_certificate_directory
      puts "Creating certificate directory at #{certificate_directory.colorize(:green)}."
      FileUtils.mkdir_p certificate_directory
    end

    def certificate_directory
      "#{@settings.project_root}/terraform/certs"
    end
  end
end
