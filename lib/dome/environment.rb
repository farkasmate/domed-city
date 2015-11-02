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

      invalid_account_notification(account) unless is_valid_account? @account
      invalid_environment_notification(account, environment) unless is_valid_env?(@account, @environment)

      set_creds(@account)
    end

    def cd_to_tf_dir
      Dir.chdir(current_env_dir) if Dir.pwd != current_env_dir
    end

    def set_creds(account)
      begin
        @aws_creds = AWS::ProfileParser.new.get(account)
      rescue RuntimeError
        raise "No credentials found for account: '#{account}'."
      end
      ENV['AWS_ACCESS_KEY_ID']     = @aws_creds[:access_key_id]
      ENV['AWS_SECRET_ACCESS_KEY'] = @aws_creds[:secret_access_key]
      ENV['AWS_DEFAULT_REGION']    = @aws_creds[:region]
    end

    def is_valid_account?(account)
      valid_accounts.include? account
    end

    def is_valid_env?(account, environment)
      if valid_accounts[valid_accounts.index(account)] == 'deirdre-dev'
        valid_env_nonprod.include? environment
      elsif valid_accounts[valid_accounts.index(account)] == 'deirdre-prd'
        valid_env_prod.include? environment
      end
    end

    def invalid_account_notification(account)
      puts "\n'#{account}' is not a valid account.\n".colorize(:red)
      puts "Valid accounts are: #{valid_accounts}."
      puts "\nEither:"
      puts "1. Set your .aws/config to one of the valid accounts above."
      puts "2. Ensure you are running this from the correct directory."
      exit 1
    end

    def invalid_environment_notification(account, environment)
      puts "\n'#{environment}' is not a valid environment for the account: '#{account}'.\n".colorize(:red)
      (account == 'deirdre-dev') ? env = valid_env_nonprod : env = valid_env_prod
      puts "Valid environments are: #{env}"
      exit 1
    end

    def s3_bucket_exists?(tfstate_bucket)
      s3_client = Aws::S3::Client.new(@aws_creds)
      resp      = s3_client.list_buckets
      resp.buckets.each { |bucket| return true if bucket.name == tfstate_bucket }
      false
    end

    def s3_tf_create_remote_state_bucket(tfstate_bucket, tfstate_s3_obj)
      puts "initial boostrap of the S3 bucket".colorize(:green)
      s3_client = Aws::S3::Client.new(@aws_creds)
      begin
        s3_client.create_bucket({
                                  bucket: tfstate_bucket,
                                  acl:    "private"
                                })
      rescue Aws::S3::Errors::BucketAlreadyExists => e
        puts "type of exception #{e.class}".colorize(:red)
        puts "backtrace for this exception:".colorize(:red)
        puts e.backtrace
        puts "\nmake sure the bucket name is unique per whole AWS S3 service, see here for docs on uniqueness https://docs.aws.amazon.com/AmazonS3/latest/gsg/CreatingABucket.html\n\n".colorize(:red)
        exit 1
      end
      puts "enabling versioning on the S3 bucket - http://docs.aws.amazon.com/AmazonS3/latest/dev/Versioning.html".colorize(:green)
      s3_client.put_bucket_versioning({
                                        bucket:                   tfstate_bucket,
                                        versioning_configuration: {
                                          mfa_delete: "Disabled",
                                          status:     "Enabled"
                                        },
                                      })
      puts "creating an empty S3 object".colorize(:green)
      s3_client.put_object({
                             bucket: tfstate_bucket,
                             key:    tfstate_s3_obj,
                             body:   ""
                           })
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

    def plan
      puts "current dir: #{Dir.pwd}"

      delete_terraform_directory
      delete_plan_file

      get_terraform_modules
      fetch_s3_state
      create_plan
    end

    def fetch_s3_state
      command         = "terraform remote config -backend=S3"\
      " -backend-config='bucket=#{@tfstate_bucket}' -backend-config='key=#{@tfstate_s3_obj}'"
      failure_message = "something went wrong when fetching the S3 state"
      execute_command(command, failure_message)
    end

    def create_plan
      command         = "terraform plan -module-depth=1 -refresh=true -out=#{@plan} -var-file=#{@varfile}"
      failure_message = "something went wrong when creating the TF plan"
      execute_command(command, failure_message)
    end

    def execute_command(command, failure_message)
      puts "About to execute command: #{command}"
      success = system command
      puts failure_message unless success
    end

    def apply
      puts "--- running task :apply".colorize(:light_cyan)
      set_env
      cd_to_tf_dir
      set_env
      cmd = "terraform apply #{PLAN}"
      puts "\n Command to execute: #{cmd}\n\n"
      bool = system(cmd)
      fail "something went wrong when applying the TF plan" unless bool
    end

    def plan_destroy
      puts "--- running task :plandestroy".colorize(:light_cyan)
      set_env
      Dir.chdir(CURRENT_ENV_DIR)
      puts "purging older terraform module cache dir ...".colorize(:green)
      purge_terraform
      puts "purging older terraform plan ...".colorize(:green)
      FileUtils.rm_f(PLAN)
      puts "updating terraform external modules ...".colorize(:green)
      Rake::Task['tf:update'].invoke
      p PLAN
      cmd = "terraform plan -destroy -module-depth=1 -out=#{PLAN} #{@varfile}"
      puts "\nCommand to execute: \n #{cmd}\n\n"
      bool = system(cmd)
      fail "something went wrong when creating the TF plan" unless bool
    end

    def destroy
      puts "--- running task :destroy".colorize(:light_cyan)
      puts "here is the destroy plan that terraform will carry out"
      plan_destroy
      apply
    end

    def get_terraform_modules
      command         = "terraform get -update=true"
      failure_message = "something went wrong when pulling remote TF modules"
      execute_command(command, failure_message)
    end

    def bootstrap_s3_state
      set_env
      if s3_bucket_exists?(tfstate_bucket)
        puts "Bootstrap attempted, but config for account: #{ACCOUNT.colorize(:green)} and environment: #{ENVIRONMENT.colorize(:green)} already exists in S3 bucket: #{tfstate_bucket.colorize(:green)}"
        puts "synchronising the remote S3 state ..."
        cd_to_tf_dir
        cmd = "terraform remote config"\
            " -backend=S3"\
            " -backend-config='bucket=#{tfstate_bucket}' -backend-config='key=#{tfstate_s3_obj}'"\
            " -state=#{STATE_FILE_DIR}/#{REMOTE_STATE_FILE}"
        # still not clear for me if the -state in the above cmd matters
        puts "Command to execute: #{cmd}"
        bool = system(cmd)
        fail "something went wrong when creating the S3 state" unless bool
      else
        s3_tf_create_remote_state_bucket(tfstate_bucket, tfstate_s3_obj)
        puts "\nsetting up the initial terraform S3 state in the S3 bucket: #{tfstate_bucket.colorize(:green)} for account:#{ACCOUNT.colorize(:green)} and environment:#{ENVIRONMENT.colorize(:green)} ..."
        cd_to_tf_dir
        cmd = "terraform remote config"\
          " -backend=S3"\
          " -backend-config='bucket=#{tfstate_bucket}' -backend-config='key=#{tfstate_s3_obj}'"
        puts "Command to execute: #{cmd}"
        bool = system(cmd)
        fail "something went wrong when creating the S3 state" unless bool
      end
    end
  end
end
