# frozen_string_literal: true

RSpec.describe 'S3Migration tenant scope' do
  it 'scopes manifest entries to the current tenant' do
    allow(Site).to receive(:account).and_return(double('account', cname: 'one.example.com'))

    expect(S3Migration.scope).to eq 'one.example.com'
  end

  it 'has no scope outside a tenant' do
    allow(Site).to receive(:account).and_return(nil)

    expect(S3Migration.scope).to be_nil
  end
end
