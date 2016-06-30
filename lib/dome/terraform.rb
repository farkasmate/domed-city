module Dome
  class Terraform
    include Dome::Shell

    attr_reader :state

    def initialize
      @environment = Dome::Environment.new
      @state       = Dome::State.new(@environment)
      @plan_file   = "plans/#{@environment.account}-#{@environment.environment}-plan.tf"
    end

    # TODO: this method is a bit of a mess and needs looking at
    # rubocop:disable Metrics/MethodLength
    # rubocop:disable Metrics/AbcSize
    def validate_environment
      puts 'Initialising domed-city...'
      puts "* Your 'account' and 'environment' are assigned based on your current directory. "\
          "The expected directory structure is 'terraform/<account>/<environment>'".colorize(:yellow)
      puts "* Your 'project' is defined using the 'project' key in your 'itv.yaml'.".colorize(:yellow)
      puts "* Valid environments are defined using the 'environments' key in your 'itv.yaml'. "\
        "You have defined: #{@environment.environments}".colorize(:yellow)
      puts '* Valid accounts are of the format <project>-dev and <project>-prd and are calculated '\
        "automatically using your 'project' variable.".colorize(:yellow)

      puts "\nDebug output:\n------------"
      environment = @environment.environment
      account     = @environment.account
      @environment.invalid_account_message unless @environment.valid_account? account
      @environment.invalid_environment_message unless @environment.valid_environment? environment
      puts "Project: #{@environment.project.colorize(:green)}"
      puts "State S3 bucket name: #{@state.state_bucket_name.colorize(:green)}"
      puts "State file name: #{@state.state_file_name.colorize(:green)}"
      @environment.aws_credentials
      puts '----------------------------------------------------------------'
    end

    def plan
      delete_terraform_directory
      delete_plan_file
      install_terraform_modules
      @state.synchronise_s3_state(@state.state_bucket_name, @state.state_file_name)
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

    def install_terraform_modules
      command         = 'terraform get -update=true'
      failure_message = 'something went wrong when pulling remote TF modules'
      execute_command(command, failure_message)
    end

    def output
      command         = 'terraform output'
      failure_message = 'something went wrong when printing TF output variables'
      execute_command(command, failure_message)
    end
  end
end
