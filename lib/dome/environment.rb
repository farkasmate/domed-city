module Dome
  class Environment
    def initialize
      @environment    = Dir.pwd.split('/')[-1]
      @account        = Dir.pwd.split('/')[-2]
      @team           = 'deirdre'
      @tfstate_bucket = "#{@team}-tfstate-#{@environment}"
      @tfstate_s3_obj = "#{@environment}-terraform.tfstate"
      @varfile        = "params/env.tfvars"
      @plan           = "plans/#{@account}-#{@environment}-plan.tf"
    end

    # --------------------------------------------------------------
    # Environment stuff
    # --------------------------------------------------------------

    def valid_accounts
      %w(deirdre-dev deirdre-prd)
    end

    def valid_env_nonprod
      %w(infradev sit qa stg)
    end

    def valid_env_prod
      %w(infraprd prd)
    end

    def validate_environment
      puts "Environment: #{@environment}"
      puts "Account: #{@account}"

      invalid_account_message(account) unless valid_account? @account
      invalid_environment_message(account, environment) unless valid_environment?(@account, @environment)

      set_aws_credentials(@account)
    end

    def set_aws_credentials(account)
      begin
        @aws_creds = AWS::ProfileParser.new.get(account)
      rescue RuntimeError
        raise "No credentials found for account: '#{account}'."
      end
      ENV['AWS_ACCESS_KEY_ID']     = @aws_creds[:access_key_id]
      ENV['AWS_SECRET_ACCESS_KEY'] = @aws_creds[:secret_access_key]
      ENV['AWS_DEFAULT_REGION']    = @aws_creds[:region]
    end

    def valid_account?(account)
      valid_accounts.include? account
    end

    def valid_environment?(account, environment)
      if valid_accounts[valid_accounts.index(account)] == 'deirdre-dev'
        valid_env_nonprod.include? environment
      elsif valid_accounts[valid_accounts.index(account)] == 'deirdre-prd'
        valid_env_prod.include? environment
      end
    end

    def invalid_account_message(account)
      puts "\n'#{account}' is not a valid account.\n".colorize(:red)
      puts "Valid accounts are: #{valid_accounts}."
      puts "\nEither:"
      puts "1. Set your .aws/config to one of the valid accounts above."
      puts "2. Ensure you are running this from the correct directory."
      exit 1
    end

    def invalid_environment_message(account, environment)
      puts "\n'#{environment}' is not a valid environment for the account: '#{account}'.\n".colorize(:red)
      (account == 'deirdre-dev') ? env = valid_env_nonprod : env = valid_env_prod
      puts "Valid environments are: #{env}"
      exit 1
    end

    # --------------------------------------------------------------
    # Terraform commands
    # --------------------------------------------------------------

    def plan
      puts "current dir: #{Dir.pwd}"
      delete_terraform_directory
      delete_plan_file
      get_terraform_modules
      fetch_s3_state
      create_plan
    end

    def apply
      command         = "terraform apply #{@plan}"
      failure_message = "something went wrong when applying the TF plan"
      execute_command(command, failure_message)
    end

    def create_plan
      command         = "terraform plan -module-depth=1 -refresh=true -out=#{@plan} -var-file=#{@varfile}"
      failure_message = "something went wrong when creating the TF plan"
      execute_command(command, failure_message)
    end

    def delete_terraform_directory
      puts "Deleting older terraform module cache dir ...".colorize(:green)
      terraform_directory = '.terraform'
      puts "About to delete directory: #{terraform_directory}"
      FileUtils.rm_rf ".terraform/"
    end

    def delete_plan_file
      puts "Deleting older terraform plan ...".colorize(:green)
      puts "About to delete: #{@plan}"
      FileUtils.rm_f @plan
    end

    def plan_destroy
      delete_terraform_directory
      delete_plan_file
      get_terraform_modules
      create_destroy_plan
    end

    def create_destroy_plan
      command         = "terraform plan -destroy -module-depth=1 -out=#{@plan} -var-file=#{@varfile}"
      failure_message = "something went wrong when creating the TF plan"
      execute_command(command, failure_message)
    end

    def get_terraform_modules
      command         = "terraform get -update=true"
      failure_message = "something went wrong when pulling remote TF modules"
      execute_command(command, failure_message)
    end

    # S3 stuff

    def s3_client
      @s3_client ||= Aws::S3::Client.new(@aws_creds)
    end

    def s3_bucket_exists?(tfstate_bucket)
      resp = s3_client.list_buckets
      resp.buckets.each { |bucket| return true if bucket.name == tfstate_bucket }
      false
    end

    def create_bucket(name)
      begin
        s3_client.create_bucket({ bucket: name, acl: "private" })
      rescue Aws::S3::Errors::BucketAlreadyExists
        fail "The S3 bucket must be globally unique. See https://docs.aws.amazon.com/AmazonS3/latest/gsg/CreatingABucket.html".colorize(:red)
      end
    end

    def enable_bucket_versioning(bucket_name)
      puts "Enabling versioning on the S3 bucket - http://docs.aws.amazon.com/AmazonS3/latest/dev/Versioning.html".colorize(:green)
      s3_client.put_bucket_versioning({
                                        bucket:                   bucket_name,
                                        versioning_configuration: {
                                          mfa_delete: "Disabled",
                                          status:     "Enabled"
                                        },
                                      })
    end

    def put_empty_object_in_bucket(bucket_name, key_name)
      puts "Putting an empty object with key: #{key_name} into bucket: #{bucket_name}".colorize(:green)
      s3_client.put_object({
                             bucket: bucket_name,
                             key:    key_name,
                             body:   ""
                           })
    end

    def create_remote_state_bucket(tfstate_bucket, tfstate_s3_obj)
      create_bucket tfstate_bucket
      enable_bucket_versioning tfstate_bucket
      put_empty_object_in_bucket(tfstate_bucket, tfstate_s3_obj)
    end

    def bootstrap_s3_state
      if s3_bucket_exists?(@tfstate_bucket)
        synchronise_s3_state
      else
        create_remote_state_bucket(@tfstate_bucket, @tfstate_s3_obj)
      end
    end

    def synchronise_s3_state
      puts "Synchronising the remote S3 state..."
      # not clear for me if the -state in the below command matters
      command         = "terraform remote config"\
            " -backend=S3"\
            " -backend-config='bucket=#{tfstate_bucket}' -backend-config='key=#{tfstate_s3_obj}'"\
            " -state=#{STATE_FILE_DIR}/#{REMOTE_STATE_FILE}"
      failure_message = "something went wrong when creating the S3 state"
      execute_command(command, failure_message)
    end

    def synchronise_s3_state_setup
      puts "Setting up the initial terraform S3 state in the S3 bucket: #{@tfstate_bucket.colorize(:green)} for account: #{@account.colorize(:green)} and environment: #{@environment.colorize(:green)} ..."
      command         = "terraform remote config"\
          " -backend=S3"\
          " -backend-config='bucket=#{tfstate_bucket}' -backend-config='key=#{tfstate_s3_obj}'"
      failure_message = "something went wrong when creating the S3 state"
      execute_command(command, failure_message)
    end

    def fetch_s3_state
      command         = "terraform remote config -backend=S3"\
      " -backend-config='bucket=#{@tfstate_bucket}' -backend-config='key=#{@tfstate_s3_obj}'"
      failure_message = "something went wrong when fetching the S3 state"
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
