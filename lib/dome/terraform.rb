# frozen_string_literal: true

module Dome
  class Terraform
    include Dome::Shell
    include Dome::Level

    attr_reader :state

    def initialize
   
      case level
      when 'environment'
        @environment = Dome::Environment.new
        @secrets     = Dome::Secrets.new(@environment)
        @state       = Dome::State.new(@environment)
        @plan_file   = "plans/#{@environment.account}-#{@environment.environment}-plan.tf"

        puts '--- Environment terraform state location ---'
        puts "[*] S3 bucket name: #{@state.state_bucket_name.colorize(:green)}"
        puts "[*] S3 object name: #{@state.state_file_name.colorize(:green)}"
        puts
      when 'ecosystem'
        @environment = Dome::Environment.new
        @secrets     = Dome::Secrets.new(@environment)
        @state       = Dome::State.new(@environment)
        @plan_file   = "plans/#{@environment.account}-#{@environment.environment}-plan.tf"

        puts '--- Ecosystem terraform state location ---'
        puts "[*] S3 bucket name: #{@state.state_bucket_name.colorize(:green)}"
        puts "[*] S3 object name: #{@state.state_file_name.colorize(:green)}"
        puts
      end
    end

    # TODO: this method is a bit of a mess and needs looking at
    def validate_environment
      environment = @environment.environment
      account     = @environment.account
      @environment.invalid_account_message unless @environment.valid_account? account
      @environment.invalid_environment_message unless @environment.valid_environment? environment

      puts '--- AWS credentials ---'
      @environment.unset_aws_keys
      @environment.aws_credentials
    end

    def plan
      @secrets.secret_env_vars
      puts '--- Deleting old plans'
      # delete_terraform_directory # Don't delete it
      delete_plan_file
      @state.s3_state
      puts
      puts '--- Terraform init & plan ---'
      terraform_init
      create_plan
      puts
    end

    def apply
      @secrets.secret_env_vars
      command         = "terraform apply #{@plan_file}"
      failure_message = '[!] something went wrong when applying the TF plan'
      @state.s3_state
      execute_command(command, failure_message)
    end

    def create_plan
      @secrets.secret_env_vars
      @secrets.extract_certs
      FileUtils.mkdir_p 'plans'
      command         = "terraform plan -refresh=true -out=#{@plan_file} -var-file=params/env.tfvars"
      failure_message = '[!] something went wrong when creating the TF plan'
      execute_command(command, failure_message)
    end

    def delete_terraform_directory
      puts '[*] Deleting terraform module cache dir ...'.colorize(:green)
      terraform_directory = '.terraform'
      FileUtils.rm_rf terraform_directory
    end

    def delete_plan_file
      puts '[*] Deleting previous terraform plan ...'.colorize(:green)
      FileUtils.rm_f @plan_file
    end

    def terraform_init
      command         = 'terraform init'
      failure_message = 'something went wrong when initialising TF'
      execute_command(command, failure_message)
    end

    def output
      command         = 'terraform output'
      failure_message = 'something went wrong when printing TF output variables'
      execute_command(command, failure_message)
    end
  end
end
