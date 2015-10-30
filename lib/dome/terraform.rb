module Dome
  class Terraform
    def self.plan
      puts "--- running task :plan".colorize(:light_cyan)
      set_env
      Dir.chdir(CURRENT_ENV_DIR)
      puts "purging older terraform module cache dir ...".colorize(:green)
      purge_terraform
      puts "purging older terraform plan ...".colorize(:green)
      FileUtils.rm_f(PLAN)
      puts "updating terraform external modules ...".colorize(:green)
      Rake::Task['tf:update'].invoke

      cmd = "terraform remote config"\
          " -backend=S3"\
          " -backend-config='bucket=#{tfstate_bucket}' -backend-config='key=#{tfstate_s3_obj}'"
      puts "Command to execute: #{cmd}"
      bool = system(cmd)
      fail "something went wrong when fetching the S3 state" unless bool
      cmd = "terraform plan -module-depth=1 -refresh=true -out=#{PLAN} #{@varfile}"
      puts "\nCommand to execute: \n #{cmd}\n\n"
      bool = system(cmd)
      fail "something went wrong when creating the TF plan" unless bool
    end

    def self.apply
      puts "--- running task :apply".colorize(:light_cyan)
      set_env
      cd_to_tf_dir
      set_env
      cmd = "terraform apply #{PLAN}"
      puts "\n Command to execute: #{cmd}\n\n"
      bool = system(cmd)
      fail "something went wrong when applying the TF plan" unless bool
    end

    def self.plan_destroy
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

    def self.destroy
      puts "--- running task :destroy".colorize(:light_cyan)
      puts "here is the destroy plan that terraform will carry out"
      plan_destroy
      apply
    end

    def self.update
      puts "--- running task :update".colorize(:light_cyan)
      cmd = "terraform get -update=true"
      puts "\nCommand to execute: \n #{cmd}\n\n"
      bool = system(cmd)
      fail "something went wrong when pulling remote TF modules" unless bool
    end

    def self.bootstrap_s3_state
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
