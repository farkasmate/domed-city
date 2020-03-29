# frozen_string_literal: true

# This class represents the current directory

module Dome
  class Level
    attr_reader :account, :ecosystem, :environment, :services

    BANNER = <<-'MSG'

             _
          __| | ___  _ __ ___   ___
        /  _` |/ _ \| '_ ` _ \ / _ \
        | (_| | (_) | | | | | |  __/
         \__,_|\___/|_| |_| |_|\___|

        Wrapping terraform since 2015
    MSG

    LEVEL_REGEX = %r{terraform/relative/path/to/level}.freeze

    def self.match(relative_path)
      # TODO: Error class
      raise "Define LEVEL_REGEX in class: #{self}" if self::LEVEL_REGEX == Dome::Level::LEVEL_REGEX

      self::LEVEL_REGEX.match(relative_path)
    end

    def self.create_level(relative_path)
      # TODO: Load non-loaded plugins only
      Dir.glob(File.expand_path('level/*.rb', __dir__)).sort.each { |file| require file }
      plugins = ObjectSpace.each_object(Class).select { |klass| klass < self && klass.name }

      plugin = plugins.find { |p| p.match(relative_path) }

      raise PluginNotFoundError, 'You might miss a plugin.' unless plugin

      plugin.new(relative_path)
    end

    def self.level_name
      /^Dome::(?<short_name>\w*)Level$/.match(name)[:short_name].downcase
    end

    def initialize(relative_path)
      # TODO: Error class
      raise 'Inherit from Dome::Level' if self.class == Dome::Level

      ENV['AWS_DEFAULT_REGION'] = 'eu-west-1'

      Logger.debug BANNER
      Logger.info "[*] Operating at #{self.class.level_name.colorize(:red)} level"

      match = self.class.match(relative_path)
      matched_symbols = Hash[match.names.map(&:to_sym).zip(match.captures)]

      @product     ||= matched_symbols[:product]
      @ecosystem   ||= matched_symbols[:ecosystem]
      @account     ||= "#{@product}-#{@ecosystem}"
      @environment ||= matched_symbols[:environment]

      @sudo ||= false

      @product = Settings['product']
      @project = Settings['project'] # FIXME: Do we need both?

      @account_id = begin
                      Settings['aws'][@ecosystem]['account_id'].to_s
                    rescue NoMethodError
                      nil
                    end

      # FIXME: Do better validation/parsing
      cidr_ecosystem = []
      cidr_ecosystem_dev = []
      cidr_ecosystem_prd = []

      ecosystem_environments     = begin
                                     Settings['aws'][@ecosystem]['environments'].keys
                                   rescue NoMethodError
                                     []
                                   end

      dev_ecosystem_environments = begin
                                     Settings['aws']['dev']['environments'].keys
                                   rescue NoMethodError
                                     []
                                   end

      prd_ecosystem_environments = begin
                                     Settings['aws']['prd']['environments'].keys
                                   rescue NoMethodError
                                     []
                                   end

      ecosystem_environments.each do |k|
        cidr_ecosystem << Settings['aws'][@ecosystem]['environments'][k.to_s]['aws_vpc_cidr']
      end

      dev_ecosystem_environments.each do |k|
        cidr_ecosystem_dev << Settings['aws']['dev']['environments'][k.to_s]['aws_vpc_cidr']
      end

      prd_ecosystem_environments.each do |k|
        cidr_ecosystem_prd << Settings['aws']['prd']['environments'][k.to_s]['aws_vpc_cidr']
      end

      ENV['TF_VAR_product']        = @product.to_s
      ENV['TF_VAR_envname']        = @environment.to_s
      ENV['TF_VAR_env']            = @environment.to_s
      ENV['TF_VAR_ecosystem']      = @ecosystem.to_s
      ENV['TF_VAR_aws_account_id'] = @account_id.to_s

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

      # NOTE: From terraform.rb
      Logger.info "--- #{self.class.level_name.capitalize} terraform state location ---"
      Logger.info "[*] S3 bucket name: #{state_bucket_name.colorize(:green)}"
      Logger.info "[*] S3 object name: #{state_file_name.colorize(:green)}"
    end

    def state_bucket_name
      # TODO: Error class
      raise "Override state_bucket_name in class: #{self.class}"
    end

    def state_file_name
      "#{self.class.level_name}.tfstate"
    end

    def plan_file
      "plans/#{self.class.level_name}-plan.tf"
    end

    # TODO: Move to initialize?
    def init_s3_state
      @state.s3_state(state_bucket_name, state_file_name)
    end

    def accounts
      %W[#{@project}-dev #{@project}-prd]
    end

    def environments
      ecosystems = Settings['ecosystems']
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
        ENV['AWS_ACCESS_KEY_ID'] = assumed_role.credentials.access_key_id.to_s
        ENV['AWS_SECRET_ACCESS_KEY'] = assumed_role.credentials.secret_access_key.to_s
        ENV['AWS_SESSION_TOKEN'] = assumed_role.credentials.session_token.to_s
      end
    end

    def aws_credentials
      Logger.info "[*] Attempting to assume the role defined by your profile for #{@account.colorize(:green)}."
      role_opts = { profile: account, role_session_name: account, use_mfa: true }

      if @sudo
        account_id = Settings['aws'][@ecosystem.to_s]['account_id'].to_s
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
