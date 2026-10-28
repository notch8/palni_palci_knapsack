# frozen_string_literal: true

RSpec.describe 'S3Migration tenant scope' do
  it 'scopes manifest entries to the current tenant' do
    allow(Site).to receive(:account).and_return(double('account', cname: 'one.example.com'))

    expect(S3Migration.scope).to eq 'one.example.com'
  end

  it 'refuses outside a tenant, where an unscoped purge would reach every tenant' do
    allow(Site).to receive(:account).and_return(nil)

    expect { S3Migration.scope }.to raise_error(ArgumentError, /inside a tenant/)
  end
end
