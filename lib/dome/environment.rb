module Dome
  class Environment
    attr_reader :environment, :account, :settings

    def initialize(directories = Dir.pwd.split('/'))
      @environment = directories[-1]
      @account     = directories[-2]
      @settings    = Dome::Settings.new
    end

    def team
      @settings.parse['project']
    end

    def accounts
      %W(#{team}-dev #{team}-prd)
    end

    def non_production_environments
      @settings.parse['environments']
    end

    def production_environments
      @settings.parse['environments']
    end

    def aws_credentials
      @aws_credentials ||= AWS::ProfileParser.new.get(@account)
    rescue RuntimeError
      raise "No credentials found for account: '#{@account}'."
    end

    def populate_aws_access_keys
      ENV['AWS_ACCESS_KEY_ID']     = aws_credentials[:access_key_id]
      ENV['AWS_SECRET_ACCESS_KEY'] = aws_credentials[:secret_access_key]
      ENV['AWS_DEFAULT_REGION']    = aws_credentials[:region]
    end

    def valid_account?(account_name)
      puts "Account: #{account_name.colorize(:green)}"
      accounts.include? account_name
    end

    def valid_environment?(account_name, environment_name)
      puts "Environment: #{environment_name.colorize(:green)}"
      if account_name.split('-')[1] == 'dev'
        non_production_environments.include? environment_name
      else
        production_environments.include? environment_name
      end
    end

    def invalid_account_message
      puts "\n'#{@account}' is not a valid account.\n".colorize(:red)
      puts "The 'account' and 'environment' variables are assigned based on your current directory.\n".colorize(:red)
      puts "The expected directory structure is '.../<account>/<environment>'\n".colorize(:red)
      puts "Valid accounts are: #{accounts}."
      puts "\nEither:"
      puts '1. Set your .aws/config to one of the valid accounts above.'
      puts '2. Ensure you are running this from the correct directory.'
      exit 1
    end

    def invalid_environment_message
      puts "\n'#{@environment}' is not a valid environment for the account: '#{@account}'.\n".colorize(:red)
      puts "The 'account' and 'environment' variables are assigned based on your current directory.\n".colorize(:red)
      puts "The expected directory structure is '.../<account>/<environment>'\n".colorize(:red)

      env = if account[-4..-1] == '-dev'
              non_production_environments
            else
              production_environments
            end
      puts "Valid environments are: #{env}."
      exit 1
    end
  end
end
