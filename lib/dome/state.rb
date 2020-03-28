# frozen_string_literal: true

module Dome
  class State
    include Dome::Helper::Shell
    include Dome::Helper::Level

    def initialize(level)
      @level = level
    end

    def state_bucket_name
      case level
      when 'environment'
        "itv-terraform-state-#{@level.project}-#{@level.ecosystem}-#{@level.environment}"
      when 'ecosystem'
        "itv-terraform-state-#{@level.project}-#{@level.ecosystem}"
      when 'product'
        "itv-terraform-state-#{@level.project}"
      when 'roles'
        "itv-terraform-state-#{@level.project}-#{@level.ecosystem}-#{@level.environment}-roles"
      when 'services'
        "itv-terraform-state-#{@level.project}-#{@level.ecosystem}-#{@level.environment}-services"
      when /^secrets-/
        "itv-terraform-state-#{@level.project}-#{@level.ecosystem}-#{@level.environment}-secrets"
      else
        Logger.error "Invalid level: #{level}".colorize(:red)
      end
    end

    def state_file_name
      case level
      when 'environment'
        "#{@level.level}.tfstate"
      when 'ecosystem'
        "#{@level.level}.tfstate"
      when 'product'
        "#{@level.level}.tfstate"
      when 'roles'
        "#{@level.level}.tfstate"
      when 'services'
        "#{@level.project}-#{@level.ecosystem}-#{@level.environment}-#{@level.services}.tfstate"
      when /^secrets-/
        "#{@level.level}.tfstate"
      else
        Logger.error "Invalid level: #{level}".colorize(:red)
      end
    end

    def s3_client
      @s3_client ||= Aws::S3::Client.new
    end

    def ddb_client
      @ddb_client ||= Aws::DynamoDB::Client.new
    end

    def list_buckets
      s3_client.list_buckets
    end

    def bucket_names
      bucket_names = list_buckets.buckets.map(&:name)
      # TODO: Add a debug flag to enable certain output
      # Logger.debug "Found the following buckets: #{bucket_names}".colorize(:yellow)
      bucket_names
    end

    def s3_bucket_exists?(bucket_name)
      bucket_names.find { |bucket| bucket == bucket_name }
    end

    def create_bucket(name)
      s3_client.create_bucket(bucket: name, acl: 'private')
    rescue Aws::S3::Errors::BucketAlreadyExists
      raise 'The S3 bucket must be globally unique. See https://docs.aws.amazon.com/AmazonS3/latest/gsg/CreatingABucket.html'.colorize(:red)
    end

    def enable_bucket_versioning(bucket_name)
      Logger.debug 'Enabling versioning on the S3 bucket - http://docs.aws.amazon.com/AmazonS3/latest/dev/Versioning.html'.colorize(:green)
      s3_client.put_bucket_versioning(bucket: bucket_name,
                                      versioning_configuration: {
                                        mfa_delete: 'Disabled',
                                        status: 'Enabled'
                                      })
    end

    def put_empty_object_in_bucket(bucket_name, key_name)
      Logger.debug "Putting an empty object with key: #{key_name} into bucket: #{bucket_name}".colorize(:green)
      s3_client.put_object(
        bucket: bucket_name,
        key: key_name,
        body: ''
      )
    end

    def dynamodb_configured?(bucket_name)
      # if the describe works, we know it exists
      ddb_client.describe_table(
        table_name: bucket_name
      )
    rescue Aws::DynamoDB::Errors::ResourceNotFoundException => e
      Logger.debug "[*] DynamoDB state locking table doesn't exist! #{e} .. creating it".colorize(:yellow)
      false
    rescue StandardError => e
      raise "Could not read DynamoDB table! error occurred: #{e}"
    end

    def setup_dynamodb(bucket_name)
      resp = ddb_client.create_table(
        attribute_definitions: [{ attribute_name: 'LockID', attribute_type: 'S' }],
        table_name: bucket_name,
        key_schema: [{ attribute_name: 'LockID', key_type: 'HASH' }],
        provisioned_throughput: {
          read_capacity_units: 1,
          write_capacity_units: 1
        }
      )
      raise unless resp.to_h[:table_description][:table_name] == bucket_name
    rescue StandardError => e
      raise "Could not create DynamoDB table! error occurred: #{e}".colorize(:red)
    end

    def create_remote_state_bucket(bucket_name, state_file)
      create_bucket bucket_name
      enable_bucket_versioning bucket_name
      put_empty_object_in_bucket(bucket_name, state_file)
    end

    def s3_state
      if s3_bucket_exists?(state_bucket_name)
        setup_dynamodb(state_bucket_name) unless dynamodb_configured?(state_bucket_name)
      else
        create_remote_state_bucket(state_bucket_name, state_file_name)
      end
    end
  end
end
