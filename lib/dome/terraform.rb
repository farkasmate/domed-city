# frozen_string_literal: true

require 'zip'

module Dome
  class Terraform
    include Dome::Helper::Shell
    include Dome::Helper::Level

    attr_reader :state

    def initialize(sudo: false)
      case level
      when 'environment'
        @environment = Dome::Environment.new
        @secrets     = Dome::Secrets.new(@environment)
        @state       = Dome::State.new(@environment)
        @plan_file   = "plans/#{@environment.account}-#{@environment.environment}-plan.tf"

        puts '--- Environment terraform state location ---'
        puts "[*] S3 bucket name: #{@state.state_bucket_name.colorize(:green)}"
        puts "[*] S3 object name: #{@state.state_file_name.colorize(:green)}"
        puts
      when 'ecosystem'
        @environment = Dome::Environment.new
        @secrets     = Dome::Secrets.new(@environment)
        @state       = Dome::State.new(@environment)
        @plan_file   = "plans/#{@environment.level}-plan.tf"

        puts '--- Ecosystem terraform state location ---'
        puts "[*] S3 bucket name: #{@state.state_bucket_name.colorize(:green)}"
        puts "[*] S3 object name: #{@state.state_file_name.colorize(:green)}"
        puts
      when 'product'
        @environment = Dome::Environment.new
        @secrets     = Dome::Secrets.new(@environment)
        @state       = Dome::State.new(@environment)
        @plan_file   = "plans/#{@environment.level}-plan.tf"

        puts '--- Product terraform state location ---'
        puts "[*] S3 bucket name: #{@state.state_bucket_name.colorize(:green)}"
        puts "[*] S3 object name: #{@state.state_file_name.colorize(:green)}"
        puts
      when 'roles'
        @environment = Dome::Environment.new
        @secrets     = Dome::Secrets.new(@environment)
        @state       = Dome::State.new(@environment)
        @plan_file   = "plans/#{@environment.level}-plan.tf"

        puts '--- Role terraform state location ---'
        puts "[*] S3 bucket name: #{@state.state_bucket_name.colorize(:green)}"
        puts "[*] S3 object name: #{@state.state_file_name.colorize(:green)}"
        puts
      when 'services'
        @environment = Dome::Environment.new
        @secrets     = Dome::Secrets.new(@environment)
        @state       = Dome::State.new(@environment)
        @plan_file   = "plans/#{@environment.services}-plan.tf"

        puts '--- Services terraform state location ---'
        puts "[*] S3 bucket name: #{@state.state_bucket_name.colorize(:green)}"
        puts "[*] S3 object name: #{@state.state_file_name.colorize(:green)}"
        puts
      when /^secrets-/
        @environment = Dome::Environment.new
        @secrets     = Dome::Secrets.new(@environment)
        @state       = Dome::State.new(@environment)
        @plan_file   = "plans/#{@environment.level}-plan.tf"

        puts '--- Secrets terraform state location ---'
        puts "[*] S3 bucket name: #{@state.state_bucket_name.colorize(:green)}"
        puts "[*] S3 object name: #{@state.state_file_name.colorize(:green)}"
        puts
      else
        puts '[*] Dome is meant to run from either a product,ecosystem,environment,role,services or secrets level'
        raise Dome::InvalidLevelError.new, level
      end

      @environment.sudo if sudo
    end

    # TODO: this method is a bit of a mess and needs looking at
    # FIXME: Simplify *validate_environment*
    # rubocop:disable Metrics/PerceivedComplexity
    def validate_environment
      case level
      when 'environment'
        puts '--- AWS credentials for accessing environment state ---'
        environment = @environment.environment
        account     = @environment.account
        @environment.invalid_account_message unless @environment.valid_account? account
        @environment.invalid_environment_message unless @environment.valid_environment? environment
        @environment.unset_aws_keys
        @environment.aws_credentials
      when 'ecosystem'
        puts '--- AWS credentials for accessing ecosystem state ---'
        @environment.unset_aws_keys
        @environment.aws_credentials
      when 'product'
        puts '--- AWS credentials for accessing product state ---'
        @environment.unset_aws_keys
        @environment.aws_credentials
      when 'roles'
        puts '--- AWS credentials for accessing roles state ---'
        environment = @environment.environment
        account     = @environment.account
        @environment.invalid_account_message unless @environment.valid_account? account
        @environment.invalid_environment_message unless @environment.valid_environment? environment
        @environment.unset_aws_keys
        @environment.aws_credentials
      when 'services'
        puts '--- AWS credentials for accessing services state ---'
        environment = @environment.environment
        account     = @environment.account
        @environment.invalid_account_message unless @environment.valid_account? account
        @environment.invalid_environment_message unless @environment.valid_environment? environment
        @environment.unset_aws_keys
        @environment.aws_credentials
      when /^secrets-/
        puts '--- AWS credentials for accessing secrets state ---'
        environment = @environment.environment
        account     = @environment.account
        @environment.invalid_account_message unless @environment.valid_account? account
        @environment.invalid_environment_message unless @environment.valid_environment? environment
        @environment.unset_aws_keys
        @environment.aws_credentials

        puts '--- Vault login ---'
        begin
          require 'vault/helper'
        rescue LoadError
          raise '[!] Failed to load vault/helper. Please add \
"gem \'hiera-vault\', git: \'git@github.com:ITV/hiera-vault\', ref: \'v1.0.0\'" or later to your Gemfile'.colorize(:red)
        end

        product = ENV['TF_VAR_product']
        environment_name = @environment.environment
        Vault.address = "https://secrets.#{environment_name}.#{product}.itv.com:8200"

        case level
        when 'secrets-init'
          Vault.address = "https://secrets-init.#{environment_name}.#{product}.itv.com:8200"
          role = 'service_administrator'
          unless Vault::Helper.initialized?
            init_user = ENV['VAULT_INIT_USER'] || 'tomclar'
            keys = Vault::Helper.init(init_user: init_user)
            puts "[*] Root token for #{init_user}: #{keys[:root_token]}".colorize(:yellow)
            puts "[*] Recovery key for #{init_user}: #{keys[:recovery_key]}".colorize(:yellow)
            raise "Vault not initialized, send the keys printed above to #{init_user} to finish initialization."
          end
        when 'secrets-config'
          role = 'content_administrator'
        else
          raise Dome::InvalidLevelError.new, level
        end

        if ENV['VAULT_TOKEN']
          puts '[*] Using VAULT_TOKEN environment variable'.colorize(:yellow)
          Vault.token = ENV['VAULT_TOKEN']
        else
          puts "[*] Logging in as: #{role}"
          ENV['VAULT_TOKEN'] = Vault::Helper.login(role)
        end

        puts ''
      else
        raise Dome::InvalidLevelError.new, level
      end
    end
    # rubocop:enable Metrics/PerceivedComplexity

    def plan
      puts '--- Decrypting hiera secrets and pass them as TF_VARs ---'
      @secrets.secret_env_vars
      puts '--- Deleting old plans'
      # delete_terraform_directory # Don't delete it
      delete_plan_file
      @state.s3_state
      puts
      puts '--- Terraform init & plan ---'
      puts
      terraform_init
      puts
      create_plan
      puts
    end

    def apply
      @secrets.secret_env_vars
      command         = "terraform apply #{@plan_file}"
      failure_message = '[!] something went wrong when applying the TF plan'
      @state.s3_state
      execute_command(command, failure_message)
    end

    def refresh
      command         = 'terraform refresh'
      failure_message = '[!] something went wrong when doing terraform refresh'
      execute_command(command, failure_message)
    end

    def statecmd(arguments)
      command         = "terraform state #{arguments}"
      failure_message = "[!] something went wrong when doing terraform state #{arguments}"
      execute_command(command, failure_message)
    end

    def console
      @secrets.secret_env_vars
      command         = 'terraform console'
      failure_message = '[!] something went wrong when doing terraform console'
      execute_command(command, failure_message)
    end

    def create_plan
      case level
      when 'environment'
        @secrets.extract_certs
        FileUtils.mkdir_p 'plans'
        command         = "terraform plan -refresh=true -out=#{@plan_file} -var-file=params/env.tfvars"
        failure_message = '[!] something went wrong when creating the environment TF plan'
        execute_command(command, failure_message)
      when 'ecosystem'
        FileUtils.mkdir_p 'plans'
        command         = "terraform plan -refresh=true -out=#{@plan_file}"
        failure_message = '[!] something went wrong when creating the ecosystem TF plan'
        execute_command(command, failure_message)
      when 'product'
        FileUtils.mkdir_p 'plans'
        command         = "terraform plan -refresh=true -out=#{@plan_file}"
        failure_message = '[!] something went wrong when creating the product TF plan'
        execute_command(command, failure_message)
      when 'roles'
        @secrets.extract_certs
        FileUtils.mkdir_p 'plans'
        command         = "terraform plan -refresh=true -out=#{@plan_file}"
        failure_message = '[!] something went wrong when creating the role TF plan'
        execute_command(command, failure_message)
      when 'services'
        @secrets.extract_certs
        FileUtils.mkdir_p 'plans'
        command         = "terraform plan -refresh=true -out=#{@plan_file} -var-file=../../params/env.tfvars"
        failure_message = '[!] something went wrong when creating the service TF plan'
        execute_command(command, failure_message)
      when /^secrets-/
        @secrets.extract_certs
        FileUtils.mkdir_p 'plans'
        command         = "terraform plan -refresh=true -out=#{@plan_file}"
        failure_message = '[!] something went wrong when creating the secret TF plan'
        execute_command(command, failure_message)
      else
        raise Dome::InvalidLevelError.new, level
      end
    end

    def delete_terraform_directory
      puts '[*] Deleting terraform module cache dir ...'.colorize(:green)
      terraform_directory = '.terraform'
      FileUtils.rm_rf terraform_directory
    end

    def delete_plan_file
      puts '[*] Deleting previous terraform plan ...'.colorize(:green)
      FileUtils.rm_f @plan_file
    end

    def init
      @state.s3_state
      sleep 5
      terraform_init
    end

    def terraform_init
      extra_params = configure_providers

      command         = "terraform init #{extra_params}"
      failure_message = 'something went wrong when initialising TF'
      execute_command(command, failure_message)
    end

    def output
      command         = 'terraform output'
      failure_message = 'something went wrong when printing TF output variables'
      execute_command(command, failure_message)
    end

    def spawn_environment_shell
      @environment.unset_aws_keys
      @environment.aws_credentials
      @secrets.secret_env_vars

      shell = ENV['SHELL'] || '/bin/sh'
      system shell
    end

    private

    def configure_providers
      providers_config = File.join(@environment.settings.project_root, '.terraform-providers.yaml')
      return unless File.exist? providers_config

      puts 'Installing providers...'.colorize(:yellow)
      plugin_dirs = []
      providers = YAML.load_file(providers_config)

      return unless providers

      providers.each do |name, version|
        plugin_dirs << install_provider(name, version)
      end

      plugin_dirs.map { |dir| "-plugin-dir #{dir}" }.join(' ')
    end

    def install_provider(name, version)
      puts "Installing provider #{name}:#{version} ...".colorize(:green)

      if RUBY_PLATFORM =~ /linux/
        arch = 'linux_amd64'
      elsif RUBY_PLATFORM =~ /darwin/
        arch = 'darwin_amd64'
      else
        raise 'Invalid platform, only linux and darwin are supported.'
      end

      uri = "https://releases.hashicorp.com/terraform-provider-#{name}/#{version}/terraform-provider-#{name}_#{version}_#{arch}.zip"
      dir = File.join(Dir.home, '.terraform.d', 'providers', name, version)

      return dir unless Dir[File.join(dir, '*')].empty? # Ruby >= 2.4: Dir.empty? dir

      FileUtils.makedirs(dir, mode: 0o0755)

      content = URI.parse(uri).open
      Zip::File.open_buffer(content) do |zip|
        zip.each do |entry|
          entry_file = File.join(dir, entry.name)
          entry.extract(entry_file)
          FileUtils.chmod(0o0755, entry_file)
        end
      end

      dir
    end
  end
end
