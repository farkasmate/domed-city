require 'spec_helper'

describe Dome::State do
  let(:environment) { 'qa' }
  let(:dome_state) { Dome::State.new(environment) }

  it 'identifies if an S3 bucket exists' do
    bucket_name = 'foo'
    s3_buckets = [double(name: 'bar'), double(name: 'baz')]
    allow(dome_state).to receive(:bucket_names) { s3_buckets }
    expect(dome_state.s3_bucket_exists?(bucket_name)).to be_falsey
  end

  it 'identifies if an S3 bucket does not exist' do
    bucket_name = 'baz'
    s3_buckets = [double(name: 'bar'), double(name: 'baz')]
    allow(dome_state).to receive(:bucket_names) { s3_buckets }
    expect(dome_state.s3_bucket_exists?(bucket_name)).to be_truthy
  end
end
