module Dome
  class Environment

    def self.validate_environment
      current_dir = File.absolute_path(ENV['PWD'])
      environment = current_dir.to_s.split('/')[-1]
      account     = current_dir.to_s.split('/')[-2]

      valid_accounts    = ['deirdre-dev', 'deirdre-prd']
      valid_env_nonprod = ['infradev', 'sit', 'qa', 'stg']
      valid_env_prod    = ['infraprd', 'prd']

      if account
        if is_valid_account?(account)
          puts "found valid account #{account}, moving on ...".colorize(:green)
        else
          invalid_account_notification
        end
      else
        fail "\n#{account} is no a valid account\n\n".colorize(:red)
      end

      if environment
        if is_valid_env?(environment)
          puts "found valid environment #{environment}, moving on ...".colorize(:green)
        else
          invalid_environment_notification
        end
      else
        fail "\n #{environment} is not a valid environment for the account: #{account}\n\n".colorize(:red)
      end

      current_env_dir = "#{account}/#{environment}"
      @varfile        = "-var-file=params/env.tfvars"
    end

    def self.cd_to_tf_dir
      Dir.chdir(current_env_dir) if Dir.pwd != current_env_dir
    end

    def self.purge_terraform
      FileUtils.rm_rf ".terraform/"
    end

    def self.set_env
      fail "Unable to set an account!" if account.nil?
      set_creds
    end

    def self.set_creds
      accounts = AWS::ProfileParser.new
      begin
        @aws_creds = accounts.get(account)
      rescue StandardError
        raise "No credentials found for #{account}"
      end
      ENV['AWS_ACCESS_KEY_ID']     = @aws_creds[:access_key_id]
      ENV['AWS_SECRET_ACCESS_KEY'] = @aws_creds[:secret_access_key]
      ENV['AWS_DEFAULT_REGION']    = @aws_creds[:region]
    end

    def self.is_valid_account?(account)
      valid_accounts.include?(account)
    end

    def self.is_valid_env?(environment)
      if valid_accounts[valid_accounts.index(account)] == 'deirdre-dev'
        valid_env_nonprod.include?(environment)
      elsif valid_accounts[valid_accounts.index(account)] == 'deirdre-prd'
        valid_env_prod.include?(environment)
      end
    end

    def self.invalid_account_notification
      puts "\n#{account} is not a valid account\n\n".colorize(:red)
      puts "valid accounts are: "
      p valid_accounts
      puts "please set your .aws/config to one of the valid accounts described above!"
      puts "if you've correctly set your .aws/config then make sure you've cd into the correct directory matching the env name from .aws/config"
      exit 1
    end

    def self.invalid_environment_notification
      puts "\n#{environment} is not a valid environment\n\n".colorize(:red)
      puts "valid environments are:"
      if account == 'deirdre-dev'
        p valid_env_nonprod
      elsif account == 'deirdre-prd'
        p valid_env_prod
      end
      exit 1
    end

    def self.s3_bucket_exists?(tfstate_bucket)
      s3_client = Aws::S3::Client.new(@aws_creds)
      resp      = s3_client.list_buckets
      resp.buckets.each { |bucket| return true if bucket.name == tfstate_bucket }
      false
    end

    def self.s3_tf_create_remote_state_bucket(tfstate_bucket, tfstate_s3_obj)
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
  end
end
