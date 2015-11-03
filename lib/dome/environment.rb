module Dome
  class Environment
    attr_reader :environment, :account

    def initialize
      directories  = Dir.pwd.split('/')
      @environment = directories[-1]
      @account     = directories[-2]
    end

    def team
      @account.match(/(\w+)-\w+\z/)[1]
    end

    def accounts
      %w(deirdre-dev deirdre-prd)
    end

    def non_production_environments
      %w(infradev sit qa stg)
    end

    def production_environments
      %w(infraprd prd)
    end

    def aws_credentials
      begin
        @aws_credentials ||= AWS::ProfileParser.new.get(@account)
      rescue RuntimeError
        raise "No credentials found for account: '#{@account}'."
      end
    end

    def populate_aws_access_keys
      ENV['AWS_ACCESS_KEY_ID']     = aws_credentials[:access_key_id]
      ENV['AWS_SECRET_ACCESS_KEY'] = aws_credentials[:secret_access_key]
      ENV['AWS_DEFAULT_REGION']    = aws_credentials[:region]
    end

    def valid_account?(account)
      puts "Account: #{account.colorize(:green)}"
      accounts.include? account
    end

    def valid_environment?(account, environment)
      puts "Environment: #{environment.colorize(:green)}"
      if account[-4..-1] == '-dev'
        non_production_environments.include? environment
      else
        production_environments.include? environment
      end
    end

    def invalid_account_message
      puts "\n'#{@account}' is not a valid account.\n".colorize(:red)
      puts "The 'account' and 'environment' values are calculated based on your current directory.\n".colorize(:red)
      puts "Valid accounts are: #{accounts}."
      puts "\nEither:"
      puts '1. Set your .aws/config to one of the valid accounts above.'
      puts '2. Ensure you are running this from the correct directory.'
      exit 1
    end

    def invalid_environment_message
      puts "\n'#{@environment}' is not a valid environment for the account: '#{@account}'.\n".colorize(:red)
      puts "The 'account' and 'environment' values are calculated based on your current directory.\n".colorize(:red)

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
