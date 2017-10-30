module Dome
  class Environment
    attr_reader :environment, :account, :ecosystem, :settings

    def initialize(directories = Dir.pwd.split('/'))
      @environment = directories[-1]
      @account     = directories[-2]
      @ecosystem   = directories[-2].split('-')[-1]
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
        "#{'AWS_ACCESS_KEY'.colorize(:green)} and #{'AWS_SECRET_KEY'.colorize(:green)}"
      ENV['AWS_ACCESS_KEY'] = nil
      ENV['AWS_SECRET_KEY'] = nil
      ENV['AWS_SECRET_ACCESS_KEY'] = nil
      ENV['AWS_ACCESS_KEY_ID'] = nil
      ENV['AWS_SESSION_TOKEN'] = nil
    end

    def aws_credentials
      puts "Assuming the role defined by your profile for 'account' name: "\
        "#{@account.colorize(:green)}. Requires valid Yubikey OAuth setup."
      role_opts = { profile: account, role_session_name: account, use_mfa: true}
      begin
        assumedRole=AwsAssumeRole::DefaultProvider.new(role_opts).resolve
      rescue StandardError => e
        puts "Ensure that you have your AWS config setup correctly:\n"\
             "[profile #{@account}]"\
             "role_arn = <<ARN of Role you are assuming>>"\
             "mfa_serial = automatic"\
             "source_profile = Source profile in root account"\
             "role_session_name = #{@account}"\
             "duration_seconds = 3600"\
             "yubikey_oath_name = <<e.g. Amazon Web Services:itv-root-ro@itv-root>>"
        raise e
      end

      puts "Exporting temporary credentials to environment variables "\
      "#{'AWS_ACCESS_KEY_ID'.colorize(:green)}, #{'AWS_SECRET_ACCESS_KEY'.colorize(:green)}"\
      " and #{'AWS_SESSION_TOKEN'.colorize(:green)}."
      ENV['AWS_ACCESS_KEY_ID'] = assumedRole.credentials.access_key_id
      ENV['AWS_SECRET_ACCESS_KEY'] = assumedRole.credentials.secret_access_key
      ENV['AWS_SESSION_TOKEN'] = assumedRole.credentials.session_token

      puts "Setting environment variable #{'AWS_DEFAULT_REGION'.colorize(:green)} "\
        "to #{'eu-west-1'.colorize(:green)}"
      ENV['AWS_DEFAULT_REGION'] = 'eu-west-1' # should we let people override this? doubtful
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

    # rubocop:disable Metrics/AbcSize
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
      puts 'To fix your issue, try the following:'
      puts '1. Set your .aws/config to one of the valid accounts above.'
      puts '2. Ensure you are running this from the correct directory.'
      puts '3. Update your itv.yaml with the required environments or project.'
    end
  end
end
