# frozen_string_literal: true

module Dome
  class Environment
    attr_reader :environment, :account, :ecosystem, :settings

    def initialize(directories = Dir.pwd.split('/'))
      @environment = directories[-1]
      @account     = directories[-2]
      @ecosystem   = directories[-2].split('-')[-1]
      ENV["TF_VAR_product"] = directories[-2].split('-')[-2]
      ENV["TF_VAR_envname"] = @environment
      ENV["TF_VAR_ecosystem"] = @ecosystem
      @settings    = Dome::Settings.new
    end

    def project
      @settings.parse['project']
    end

    def accounts
      %W[#{project}-dev #{project}-prd]
    end

    def environments
      ecosystems = @settings.parse['ecosystems']
      raise 'ecosystems must be a hashmap of ecosystems to environments' unless ecosystems.is_a?(Hash)
      ecosystems.values.flatten
    end

    def unset_aws_keys
      puts 'Unsetting environment variables '\
        "#{'AWS_ACCESS_KEY'.colorize(:green)}, #{'AWS_SECRET_KEY'.colorize(:green)}, "\
        "#{'AWS_ACCESS_KEY_ID'.colorize(:green)}, #{'AWS_SECRET_ACCESS_KEY'.colorize(:green)}"\
        " and #{'AWS_SESSION_TOKEN'.colorize(:green)}."
      ENV['AWS_ACCESS_KEY'] = nil
      ENV['AWS_SECRET_KEY'] = nil
      ENV['AWS_SECRET_ACCESS_KEY'] = nil
      ENV['AWS_ACCESS_KEY_ID'] = nil
      ENV['AWS_SESSION_TOKEN'] = nil
    end

    def export_aws_keys(assumed_role)
      puts 'Exporting temporary credentials to environment variables '\
      "#{'AWS_ACCESS_KEY_ID'.colorize(:green)}, #{'AWS_SECRET_ACCESS_KEY'.colorize(:green)}"\
      " and #{'AWS_SESSION_TOKEN'.colorize(:green)}."
      ENV['AWS_ACCESS_KEY_ID'] = assumed_role.credentials.access_key_id
      ENV['AWS_SECRET_ACCESS_KEY'] = assumed_role.credentials.secret_access_key
      ENV['AWS_SESSION_TOKEN'] = assumed_role.credentials.session_token

      puts "Setting environment variable #{'AWS_DEFAULT_REGION'.colorize(:green)} "\
        "to #{'eu-west-1'.colorize(:green)}"
      ENV['AWS_DEFAULT_REGION'] = 'eu-west-1' # should we let people override this? doubtful
    end

    def aws_credentials
      puts "Attempting to assume the role defined by your profile for 'account' name: "\
        "#{@account.colorize(:green)}."
      role_opts = { profile: account, role_session_name: account, use_mfa: true }
      begin
        assumed_role = AwsAssumeRole::DefaultProvider.new(role_opts).resolve
      rescue StandardError => e
        raise "ERROR: Unable to assume role: #{e}".colorize(:red)
      end

      export_aws_keys(assumed_role)
    end

    def valid_account?(account_name)
      puts "Account: #{account_name.colorize(:green)}"
      accounts.include? account_name
    end

    def valid_environment?(environment_name)
      puts "Environment: #{environment_name.colorize(:green)}"
      environments.include? environment_name
    end

    def invalid_account_message
      puts "\n'#{@account}' is not a valid account.\n".colorize(:red)
      generic_error_message
      exit 1
    end

    def invalid_environment_message
      puts "\n'#{@environment}' is not a valid environment.\n".colorize(:red)
      generic_error_message
      exit 1
    end

    private

    def generic_error_message
      puts "The 'account' and 'environment' variables are assigned based on your current directory.\n".colorize(:red)
      puts "The expected directory structure is 'terraform/<account>/<environment>'\n".colorize(:red)
      puts '============================================================================='
      puts "Valid environments are defined using the 'environments' key in your itv.yaml."
      puts "The environments you have defined are: #{environments}."
      puts '============================================================================='
      puts 'Valid accounts are of the format <project>-dev/prd and <project>-prd' \
           " (where 'project' is defined using the 'project' key in your itv.yaml."
      puts "The accounts you have defined are: #{accounts}."
      puts '============================================================================='
      puts "To fix your issue, try the following:\n"\
        "1. Set your .aws/config to one of the valid accounts above.\n"\
        "2. Ensure you are running this from the correct directory.\n"\
        '3. Update your itv.yaml with the required environments or project.'
    end
  end
end
