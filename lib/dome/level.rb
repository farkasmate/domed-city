# frozen_string_literal: true

# This class represents the current directory

module Dome
  class Level
    attr_reader :environment, :account, :settings, :services

    include Dome::Helper::Level

    BANNER = <<-'MSG'

             _
          __| | ___  _ __ ___   ___
        /  _` |/ _ \| '_ ` _ \ / _ \
        | (_| | (_) | | | | | |  __/
         \__,_|\___/|_| |_| |_|\___|

        Wrapping terraform since 2015
    MSG

    def self.match(_relative_path)
      raise "Override self.match(relative_path) in class: #{self}"
    end

    def self.find_plugin(relative_path)
      # TODO: Load non-loaded plugins only
      Dir.glob(File.expand_path('level/*.rb', __dir__)).sort.each { |file| require file }
      plugins = ObjectSpace.each_object(Class).select { |klass| klass < self && klass.name }

      plugin = plugins.find { |p| p.match(relative_path) }

      raise PluginNotFoundError, 'You might miss a plugin.' unless plugin

      plugin
    end

    def initialize(directories = Dir.pwd.split('/'))
      ENV['AWS_DEFAULT_REGION'] = 'eu-west-1'

      Logger.debug BANNER
      Logger.info "[*] Operating at #{level.colorize(:red)} level"

      @sudo = false

      @settings               = Dome::Settings.new
      @product                = @settings.parse['product']

      case level
      when 'environment'
        @environment            = directories[-1]
        @account                = directories[-2]
        @services               = nil

      when 'ecosystem'
        @environment            = nil
        @account                = directories[-1]
        @services               = nil

      when 'product'
        @environment            = nil
        @account                = "#{@product}-prd"
        @services               = nil

      when 'roles'
        @environment            = directories[-2]
        @account                = directories[-3]
        @services               = nil

      when 'services'
        @environment            = directories[-3]
        @account                = directories[-4]
        @services               = directories[-1]

      when /^secrets-/
        @environment            = directories[-3]
        @account                = directories[-4]
        @services               = nil

      else
        Logger.error "Invalid level: #{level}".colorize(:red)
      end

      @ecosystem              = @account.split('-')[-1]
      @account_id             = @settings.parse['aws'][@ecosystem.to_s]['account_id'].to_s

      ENV['TF_VAR_product']   = @product
      ENV['TF_VAR_envname']   = @environment
      ENV['TF_VAR_env']       = @environment
      ENV['TF_VAR_ecosystem'] = @ecosystem
      ENV['TF_VAR_aws_account_id'] = @account_id

      cidr_ecosystem = []
      cidr_ecosystem_dev = []
      cidr_ecosystem_prd = []

      ecosystem_environments = @settings.parse['aws'][@ecosystem.to_s]['environments'].keys
      ecosystem_environments.each do |k|
        cidr_ecosystem << @settings.parse['aws'][@ecosystem.to_s]['environments'][k.to_s]['aws_vpc_cidr']
      end

      dev_ecosystem_environments = @settings.parse['aws']['dev']['environments'].keys
      dev_ecosystem_environments.each do |k|
        cidr_ecosystem_dev << @settings.parse['aws']['dev']['environments'][k.to_s]['aws_vpc_cidr']
      end

      prd_ecosystem_environments = @settings.parse['aws']['prd']['environments'].keys
      prd_ecosystem_environments.each do |k|
        cidr_ecosystem_prd << @settings.parse['aws']['prd']['environments'][k.to_s]['aws_vpc_cidr']
      end

      ENV['TF_VAR_cidr_ecosystem'] = cidr_ecosystem.join(',').to_s

      #
      # TODO: Will uncomment when all the products migrate to 1.1
      #

      # ENV['TF_VAR_cidr_ecosystem_dev'] = cidr_ecosystem_dev.join(',').to_s
      # ENV['TF_VAR_cidr_ecosystem_prd'] = cidr_ecosystem_prd.join(',').to_s

      ENV['TF_VAR_dev_ecosystem_environments'] = dev_ecosystem_environments.join(',').to_s
      ENV['TF_VAR_prd_ecosystem_environments'] = prd_ecosystem_environments.join(',').to_s

      Logger.info '--- Initial TF_VAR variables to drive terraform ---'
      Logger.info "[*] Setting aws_account_id to #{ENV['TF_VAR_aws_account_id'].colorize(:green)}"
      Logger.info "[*] Setting product to #{ENV['TF_VAR_product'].colorize(:green)}"
      Logger.info "[*] Setting ecosystem to #{ENV['TF_VAR_ecosystem'].colorize(:green)}"
      Logger.info "[*] Setting env to #{ENV['TF_VAR_env'].colorize(:green)}" unless ENV['TF_VAR_env'].nil?
      Logger.info "[*] Setting cidr_ecosystem to #{ENV['TF_VAR_cidr_ecosystem'].colorize(:green)}"
      Logger.info ''

      Logger.info '--- The following TF_VAR are helpers that modules can use ---'
      Logger.info "[*] Setting dev_ecosystem_environments to #{ENV['TF_VAR_dev_ecosystem_environments'].colorize(:green)}"
      Logger.info "[*] Setting prd_ecosystem_environments to #{ENV['TF_VAR_prd_ecosystem_environments'].colorize(:green)}"

      #
      # TODO: Will uncomment when all the products migrate to 1.1
      #

      # Logger.info "[*] Setting cidr_ecosystem_dev to #{ENV['TF_VAR_cidr_ecosystem_dev'].colorize(:green)}"
      # Logger.info "[*] Setting cidr_ecosystem_prd to #{ENV['TF_VAR_cidr_ecosystem_prd'].colorize(:green)}"
    end

    def project
      @settings.parse['project']
    end

    def ecosystem
      directories = Dir.pwd.split('/')
      case level
      when 'ecosystem'
        directories[-1].split('-')[-1]
      when 'environment'
        directories[-2].split('-')[-1]
      when 'product'
        # FIXME: This is 'prd' if accessed as @ecosystem
        'product'
      when 'roles'
        directories[-3].split('-')[-1]
      when /^secrets-|services/
        directories[-4].split('-')[-1]
      else
        Logger.error "Invalid level: #{level}".colorize(:red)
      end
    end

    def accounts
      %W[#{project}-dev #{project}-prd]
    end

    def environments
      ecosystems = @settings.parse['ecosystems']
      raise '[!] ecosystems must be a hashmap of ecosystems to environments' unless ecosystems.is_a?(Hash)

      ecosystems.values.flatten
    end

    def unset_aws_keys
      if ENV['FREEZE_AWS_ENVVAR']
        Logger.debug '$FREEZE_AWS_ENVVAR is set. Leaving AWS environment variables unchanged.'
      else
        Logger.debug '[*] Unsetting AWS environment variables from the shell to make sure we are using the correct'\
        'assumed roles credentials'
        ENV['AWS_ACCESS_KEY'] = nil
        ENV['AWS_SECRET_KEY'] = nil
        ENV['AWS_SECRET_ACCESS_KEY'] = nil
        ENV['AWS_ACCESS_KEY_ID'] = nil
        ENV['AWS_SESSION_TOKEN'] = nil
      end
    end

    def export_aws_keys(assumed_role)
      if ENV['FREEZE_AWS_ENVVAR']
        Logger.debug '$FREEZE_AWS_ENVVAR is set. Leaving AWS environment variables unchanged.'
      else
        Logger.debug '[*] Exporting temporary credentials to environment variables '\
        "#{'AWS_ACCESS_KEY_ID'.colorize(:green)}, #{'AWS_SECRET_ACCESS_KEY'.colorize(:green)}"\
        " and #{'AWS_SESSION_TOKEN'.colorize(:green)}."
        ENV['AWS_ACCESS_KEY_ID'] = assumed_role.credentials.access_key_id
        ENV['AWS_SECRET_ACCESS_KEY'] = assumed_role.credentials.secret_access_key
        ENV['AWS_SESSION_TOKEN'] = assumed_role.credentials.session_token
      end
    end

    def aws_credentials
      Logger.info "[*] Attempting to assume the role defined by your profile for #{@account.colorize(:green)}."
      role_opts = { profile: account, role_session_name: account, use_mfa: true }

      if @sudo
        account_id = @settings.parse['aws'][@ecosystem.to_s]['account_id'].to_s
        role_opts[:role_arn] = "arn:aws:iam::#{account_id}:role/itv-root"
      end

      begin
        assumed_role = AwsAssumeRole::DefaultProvider.new(role_opts).resolve
      rescue StandardError => e
        raise "[!] Unable to assume role, possibly yubikey related: #{e}".colorize(:red) \
      end

      if assumed_role.nil?
        raise "[!] Failed to find assume role details for #{role_opts[:profile]}" \
              ' - check your ~/.aws/config file'.colorize(:red)
      end

      export_aws_keys(assumed_role)
    end

    def valid_account?(account_name)
      accounts.include? account_name
    end

    def valid_environment?(environment_name)
      environments.include? environment_name
    end

    def invalid_account_message
      generic_error_message
      raise "\n[!] '#{@account}' is not a valid account.\n".colorize(:red)
    end

    def invalid_environment_message
      generic_error_message
      raise "\n[!] '#{@environment}' is not a valid environment.\n".colorize(:red)
    end

    def sudo
      @sudo = true
    end

    private

    def generic_error_message
      Logger.error '--- Debug --- '
      Logger.error "The environments you have defined are: #{environments}."
      Logger.error "The accounts we calculated from your project itv.yaml key are: #{accounts}."
      Logger.error '--- Troubleshoot ---'
      Logger.error 'To fix your issue, try the following:'
      Logger.error '1. Set your .aws/config to one of the valid accounts above.'
      Logger.error '2. Ensure you are running this from the correct directory.'
      Logger.error '3. Update your itv.yaml with the required environments or project.'
      Logger.error '4. Check the README in case something is missing from your setup or ask in Slack'
    end
  end
end
