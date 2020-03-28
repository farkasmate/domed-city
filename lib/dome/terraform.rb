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
        @level     = Dome::Level.new
        @secrets   = Dome::Secrets.new(@level)
        @state     = Dome::State.new(@level)
        @plan_file = "plans/#{@level.account}-#{@level.environment}-plan.tf"

        Logger.info '--- Environment terraform state location ---'
        Logger.info "[*] S3 bucket name: #{@state.state_bucket_name.colorize(:green)}"
        Logger.info "[*] S3 object name: #{@state.state_file_name.colorize(:green)}"
      when 'ecosystem'
        @level     = Dome::Level.new
        @secrets   = Dome::Secrets.new(@level)
        @state     = Dome::State.new(@level)
        @plan_file = "plans/#{@level.level}-plan.tf"

        Logger.info '--- Ecosystem terraform state location ---'
        Logger.info "[*] S3 bucket name: #{@state.state_bucket_name.colorize(:green)}"
        Logger.info "[*] S3 object name: #{@state.state_file_name.colorize(:green)}"
      when 'product'
        @level     = Dome::Level.new
        @secrets   = Dome::Secrets.new(@level)
        @state     = Dome::State.new(@level)
        @plan_file = "plans/#{@level.level}-plan.tf"

        Logger.info '--- Product terraform state location ---'
        Logger.info "[*] S3 bucket name: #{@state.state_bucket_name.colorize(:green)}"
        Logger.info "[*] S3 object name: #{@state.state_file_name.colorize(:green)}"
      when 'roles'
        @level     = Dome::Level.new
        @secrets   = Dome::Secrets.new(@level)
        @state     = Dome::State.new(@level)
        @plan_file = "plans/#{@level.level}-plan.tf"

        Logger.info '--- Role terraform state location ---'
        Logger.info "[*] S3 bucket name: #{@state.state_bucket_name.colorize(:green)}"
        Logger.info "[*] S3 object name: #{@state.state_file_name.colorize(:green)}"
      when 'services'
        @level     = Dome::Level.new
        @secrets   = Dome::Secrets.new(@level)
        @state     = Dome::State.new(@level)
        @plan_file = "plans/#{@level.services}-plan.tf"

        Logger.info '--- Services terraform state location ---'
        Logger.info "[*] S3 bucket name: #{@state.state_bucket_name.colorize(:green)}"
        Logger.info "[*] S3 object name: #{@state.state_file_name.colorize(:green)}"
      when /^secrets-/
        @level     = Dome::Level.new
        @secrets   = Dome::Secrets.new(@level)
        @state     = Dome::State.new(@level)
        @plan_file = "plans/#{@level.level}-plan.tf"

        Logger.info '--- Secrets terraform state location ---'
        Logger.info "[*] S3 bucket name: #{@state.state_bucket_name.colorize(:green)}"
        Logger.info "[*] S3 object name: #{@state.state_file_name.colorize(:green)}"
      else
        Logger.info '[*] Dome is meant to run from either a product,ecosystem,environment,role,services or secrets level'
        raise Dome::InvalidLevelError.new, level
      end

      @level.sudo if sudo
    end

    # TODO: this method is a bit of a mess and needs looking at
    # FIXME: Simplify *validate_environment*
    # rubocop:disable Metrics/PerceivedComplexity
    def validate_environment
      case level
      when 'environment'
        Logger.info '--- AWS credentials for accessing environment state ---'
        environment = @level.environment
        account     = @level.account
        @level.invalid_account_message unless @level.valid_account? account
        @level.invalid_environment_message unless @level.valid_environment? environment
        @level.unset_aws_keys
        @level.aws_credentials
      when 'ecosystem'
        Logger.info '--- AWS credentials for accessing ecosystem state ---'
        @level.unset_aws_keys
        @level.aws_credentials
      when 'product'
        Logger.info '--- AWS credentials for accessing product state ---'
        @level.unset_aws_keys
        @level.aws_credentials
      when 'roles'
        Logger.info '--- AWS credentials for accessing roles state ---'
        environment = @level.environment
        account     = @level.account
        @level.invalid_account_message unless @level.valid_account? account
        @level.invalid_environment_message unless @level.valid_environment? environment
        @level.unset_aws_keys
        @level.aws_credentials
      when 'services'
        Logger.info '--- AWS credentials for accessing services state ---'
        environment = @level.environment
        account     = @level.account
        @level.invalid_account_message unless @level.valid_account? account
        @level.invalid_environment_message unless @level.valid_environment? environment
        @level.unset_aws_keys
        @level.aws_credentials
      when /^secrets-/
        Logger.info '--- AWS credentials for accessing secrets state ---'
        environment = @level.environment
        account     = @level.account
        @level.invalid_account_message unless @level.valid_account? account
        @level.invalid_environment_message unless @level.valid_environment? environment
        @level.unset_aws_keys
        @level.aws_credentials

        Logger.info '--- Vault login ---'
        begin
          require 'vault/helper'
        rescue LoadError
          raise '[!] Failed to load vault/helper. Please add \
"gem \'hiera-vault\', git: \'git@github.com:ITV/hiera-vault\', ref: \'v1.0.0\'" or later to your Gemfile'.colorize(:red)
        end

        product = ENV['TF_VAR_product']
        environment_name = @level.environment
        Vault.address = "https://secrets.#{environment_name}.#{product}.itv.com:8200"

        case level
        when 'secrets-init'
          Vault.address = "https://secrets-init.#{environment_name}.#{product}.itv.com:8200"
          role = 'service_administrator'
          unless Vault::Helper.initialized?
            init_user = ENV['VAULT_INIT_USER'] || 'tomclar'
            keys = Vault::Helper.init(init_user: init_user)
            Logger.info "[*] Root token for #{init_user}: #{keys[:root_token]}".colorize(:yellow)
            Logger.info "[*] Recovery key for #{init_user}: #{keys[:recovery_key]}".colorize(:yellow)
            raise "Vault not initialized, send the keys printed above to #{init_user} to finish initialization."
          end
        when 'secrets-config'
          role = 'content_administrator'
        else
          raise Dome::InvalidLevelError.new, level
        end

        if ENV['VAULT_TOKEN']
          Logger.info '[*] Using VAULT_TOKEN environment variable'.colorize(:yellow)
          Vault.token = ENV['VAULT_TOKEN']
        else
          Logger.info "[*] Logging in as: #{role}"
          ENV['VAULT_TOKEN'] = Vault::Helper.login(role)
        end
      else
        raise Dome::InvalidLevelError.new, level
      end
    end
    # rubocop:enable Metrics/PerceivedComplexity

    def plan
      Logger.info '--- Decrypting hiera secrets and pass them as TF_VARs ---'
      @secrets.secret_env_vars
      Logger.info '--- Deleting old plans'
      # delete_terraform_directory # Don't delete it
      delete_plan_file
      @state.s3_state
      Logger.info '--- Terraform init & plan ---'

      terraform_init
      create_plan
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
      Logger.info '[*] Deleting terraform module cache dir ...'.colorize(:green)
      terraform_directory = '.terraform'
      FileUtils.rm_rf terraform_directory
    end

    def delete_plan_file
      Logger.info '[*] Deleting previous terraform plan ...'.colorize(:green)
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
      @level.unset_aws_keys
      @level.aws_credentials
      @secrets.secret_env_vars

      shell = ENV['SHELL'] || '/bin/sh'
      system shell
    end

    private

    def configure_providers
      providers_config = File.join(@level.settings.project_root, '.terraform-providers.yaml')
      return unless File.exist? providers_config

      Logger.info 'Installing providers...'.colorize(:yellow)
      plugin_dirs = []
      providers = YAML.load_file(providers_config)

      return unless providers

      providers.each do |name, version|
        plugin_dirs << install_provider(name, version)
      end

      plugin_dirs.map { |dir| "-plugin-dir #{dir}" }.join(' ')
    end

    def install_provider(name, version)
      Logger.info "Installing provider #{name}:#{version} ...".colorize(:green)

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
