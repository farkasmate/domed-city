# frozen_string_literal: true

require 'zip'

module Dome
  class Terraform
    include Dome::Helper::Shell
    include Dome::Helper::Level

    def initialize(relative_path, sudo = false)
      @level   = Level.create_level(relative_path)
      @secrets = Dome::Secrets.new(@level.ecosystem, @level.environment)

      @level.sudo if sudo

      # FIXME: Move validation into Level, separate setting up ENV
      @level.validate_environment
    end

    def s3_state
      @level.init_s3_state
    end

    def plan
      Logger.info '--- Decrypting hiera secrets and pass them as TF_VARs ---'
      @secrets.secret_env_vars
      Logger.info '--- Deleting old plans'
      # delete_terraform_directory # Don't delete it
      delete_plan_file
      s3_state
      Logger.info '--- Terraform init & plan ---'

      terraform_init
      create_plan
    end

    def apply
      @secrets.secret_env_vars
      command         = "terraform apply #{@level.plan_file}"
      failure_message = '[!] something went wrong when applying the TF plan'
      s3_state
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
        command         = "terraform plan -refresh=true -out=#{@level.plan_file} -var-file=params/env.tfvars"
        failure_message = '[!] something went wrong when creating the environment TF plan'
        execute_command(command, failure_message)
      when 'ecosystem'
        FileUtils.mkdir_p 'plans'
        command         = "terraform plan -refresh=true -out=#{@level.plan_file}"
        failure_message = '[!] something went wrong when creating the ecosystem TF plan'
        execute_command(command, failure_message)
      when 'product'
        FileUtils.mkdir_p 'plans'
        command         = "terraform plan -refresh=true -out=#{@level.plan_file}"
        failure_message = '[!] something went wrong when creating the product TF plan'
        execute_command(command, failure_message)
      when 'roles'
        @secrets.extract_certs
        FileUtils.mkdir_p 'plans'
        command         = "terraform plan -refresh=true -out=#{@level.plan_file}"
        failure_message = '[!] something went wrong when creating the role TF plan'
        execute_command(command, failure_message)
      when 'services'
        @secrets.extract_certs
        FileUtils.mkdir_p 'plans'
        command         = "terraform plan -refresh=true -out=#{@level.plan_file} -var-file=../../params/env.tfvars"
        failure_message = '[!] something went wrong when creating the service TF plan'
        execute_command(command, failure_message)
      when /^secrets-/
        @secrets.extract_certs
        FileUtils.mkdir_p 'plans'
        command         = "terraform plan -refresh=true -out=#{@level.plan_file}"
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
      FileUtils.rm_f @level.plan_file
    end

    def init
      s3_state
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
