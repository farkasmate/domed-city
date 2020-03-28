# frozen_string_literal: true

require 'spec_helper'

describe Dome::State do
  let(:level) { 'qa' }
  let(:dome_state) { Dome::State.new(level) }

  it 'identifies if an S3 bucket exists' do
    bucket_name = 'foo'
    s3_buckets = %w[bar baz]
    allow(dome_state).to receive(:bucket_names) { s3_buckets }
    expect(dome_state.s3_bucket_exists?(bucket_name)).to be_falsey
  end

  it 'identifies if an S3 bucket does not exist' do
    bucket_name = 'baz'
    s3_buckets = %w[bar baz]
    allow(dome_state).to receive(:bucket_names) { s3_buckets }
    expect(dome_state.s3_bucket_exists?(bucket_name)).to be_truthy
  end

  context 'parsing the AWS API response' do
    it 'extracts the bucket names correctly' do
      expected_buckets = %w[bar baz]
      s3_buckets = double(buckets: [double(name: 'bar'), double(name: 'baz')])
      allow(dome_state).to receive(:list_buckets) { s3_buckets }
      expect(dome_state.bucket_names).to match_array(expected_buckets)
    end
  end
end
