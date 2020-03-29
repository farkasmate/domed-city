# frozen_string_literal: true

require 'spec_helper'

describe Dome do
  let(:project_root) { File.realpath('spec/fixtures') }
  let(:ecosystem) { 'dev' }
  let(:environment) { 'qa' }
  let(:hiera) { Dome::HieraLookup.new(project_root, ecosystem, environment) }

  it 'outputs the correct message for a hiera lookup' do
    vars = { 'foo' => 'bar' }
    allow(hiera).to receive(:lookup).and_return('bar')

    expect(Dome::Logger).to receive(:info).with("[*] Setting \e[0;32;49mTF_VAR_foo\e[0m.")
    hiera.secret_env_vars(vars)
  end

  it 'outputs the correct error message for a failed hiera lookup' do
    vars = { 'foo' => 'bar' }
    allow(hiera).to receive(:lookup).and_return(nil)

    expect(Dome::Logger).to receive(:warn).with("\e[0;31;49m[!] Hiera lookup failed for 'bar', so TF_VAR_foo was not set.\e[0m")
    hiera.secret_env_vars(vars)
  end
end
