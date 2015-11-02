module Dome
  class Environment
    def initialize
      @environment  = Dir.pwd.split('/')[-1]
      @account      = Dir.pwd.split('/')[-2]
      @team         = 'deirdre'
      @state_bucket = "#{@team}-tfstate-#{@environment}"
      @state_file   = "#{@environment}-terraform.tfstate"
      @plan_file    = "plans/#{@account}-#{@environment}-plan.tf"
    end

    # --------------------------------------------------------------
    # Environment stuff
    # --------------------------------------------------------------

    def accounts
      %w(deirdre-dev deirdre-prd)
    end

    def non_production_environments
      %w(infradev sit qa stg)
    end

    def production_environments
      %w(infraprd prd)
    end

    def validate_environment
      invalid_account_message(@account) unless valid_account? @account
      invalid_environment_message(@account, @environment) unless valid_environment?(@account, @environment)
      set_aws_credentials @account
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
      puts "Environment: #{@environment.colorize(:green)}"
      if account[-4..-1] == '-dev'
        non_production_environments.include? environment
      else
        production_environments.include? environment
      end
    end

    def invalid_account_message(account)
      puts "\n'#{account}' is not a valid account.\n".colorize(:red)
      puts "The 'account' and 'environment' values are calculated based on your current directory.\n".colorize(:red)
      puts "Valid accounts are: #{accounts}."
      puts "\nEither:"
      puts '1. Set your .aws/config to one of the valid accounts above.'
      puts '2. Ensure you are running this from the correct directory.'
      exit 1
    end

    def invalid_environment_message(account, environment)
      puts "\n'#{environment}' is not a valid environment for the account: '#{account}'.\n".colorize(:red)
      puts "The 'account' and 'environment' values are calculated based on your current directory.\n".colorize(:red)

      env = if account[-4..-1] == '-dev'
              non_production_environments
            else
              production_environments
            end
      puts "Valid environments are: #{env}."
      exit 1
    end

    # --------------------------------------------------------------
    # Terraform commands
    # --------------------------------------------------------------

    def plan
      puts "current dir: #{Dir.pwd}"
      delete_terraform_directory
      delete_plan_file
      install_terraform_modules
      synchronise_s3_state
      create_plan
    end

    def apply
      command         = "terraform apply #{@plan_file}"
      failure_message = 'something went wrong when applying the TF plan'
      execute_command(command, failure_message)
    end

    def create_plan
      command         = "terraform plan -module-depth=1 -refresh=true -out=#{@plan_file} -var-file=params/env.tfvars"
      failure_message = 'something went wrong when creating the TF plan'
      execute_command(command, failure_message)
    end

    def delete_terraform_directory
      puts 'Deleting older terraform module cache dir ...'.colorize(:green)
      terraform_directory = '.terraform'
      puts "About to delete directory: #{terraform_directory}"
      FileUtils.rm_rf '.terraform/'
    end

    def delete_plan_file
      puts 'Deleting older terraform plan ...'.colorize(:green)
      puts "About to delete: #{@plan_file}"
      FileUtils.rm_f @plan_file
    end

    def plan_destroy
      delete_terraform_directory
      delete_plan_file
      install_terraform_modules
      create_destroy_plan
    end

    def create_destroy_plan
      command         = "terraform plan -destroy -module-depth=1 -out=#{@plan_file} -var-file=params/env.tfvars"
      failure_message = 'something went wrong when creating the TF plan'
      execute_command(command, failure_message)
    end

    def install_terraform_modules
      command         = 'terraform get -update=true'
      failure_message = 'something went wrong when pulling remote TF modules'
      execute_command(command, failure_message)
    end

    # S3 stuff

    def s3_client
      @s3_client ||= Aws::S3::Client.new(aws_credentials)
    end

    def s3_bucket_exists?(tfstate_bucket)
      resp = s3_client.list_buckets
      resp.buckets.each { |bucket| return true if bucket.name == tfstate_bucket }
      false
    end

    def create_bucket(name)
      begin
        s3_client.create_bucket(bucket: name, acl: 'private')
      rescue Aws::S3::Errors::BucketAlreadyExists
        raise 'The S3 bucket must be globally unique. See https://docs.aws.amazon.com/AmazonS3/latest/gsg/CreatingABucket.html'.colorize(:red)
      end
    end

    def enable_bucket_versioning(bucket_name)
      puts 'Enabling versioning on the S3 bucket - http://docs.aws.amazon.com/AmazonS3/latest/dev/Versioning.html'.colorize(:green)
      s3_client.put_bucket_versioning(bucket:                   bucket_name,
                                      versioning_configuration: {
                                        mfa_delete: 'Disabled',
                                        status:     'Enabled'
                                      })
    end

    def put_empty_object_in_bucket(bucket_name, key_name)
      puts "Putting an empty object with key: #{key_name} into bucket: #{bucket_name}".colorize(:green)
      s3_client.put_object(
        bucket: bucket_name,
        key:    key_name,
        body:   ''
      )
    end

    def create_remote_state_bucket(state_bucket, state_file)
      create_bucket state_bucket
      enable_bucket_versioning state_bucket
      put_empty_object_in_bucket(state_bucket, state_file)
    end

    def bootstrap_s3_state
      if s3_bucket_exists?(@state_bucket)
        synchronise_s3_state
      else
        create_remote_state_bucket(@state_bucket, @state_file)
      end
    end

    def synchronise_s3_state
      puts 'Synchronising the remote S3 state...'
      command         = 'terraform remote config -backend=S3'\
            " -backend-config='bucket=#{@state_bucket}' -backend-config='key=#{@state_file}'"
      failure_message = 'Something went wrong when synchronising the S3 state.'
      execute_command(command, failure_message)
    end

    # --------------------------------------------------------------
    # Misc.
    # --------------------------------------------------------------

    def execute_command(command, failure_message)
      puts "About to execute command: #{command}"
      success = system command
      puts failure_message unless success
    end
  end
end
