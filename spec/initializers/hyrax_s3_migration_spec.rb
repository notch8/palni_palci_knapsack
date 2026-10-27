# frozen_string_literal: true

# TEMPORARY(s3-migration): remove once the Hyku pin includes samvera/hyku#3412 (it ships this scope initializer),
# together with every other file carrying this tag.
# Find them all: git grep -l 'TEMPORARY(s3-migration)'

RSpec.describe 'Hyrax S3 migration tenant scope' do
  before { skip 'requires a Hyrax release that includes Hyrax::S3Migration' unless defined?(Hyrax::S3Migration) }

  it 'scopes manifest entries to the current tenant' do
    allow(Site).to receive(:account).and_return(double('account', cname: 'one.example.com'))

    expect(Hyrax::S3Migration.scope).to eq 'one.example.com'
  end

  it 'has no scope outside a tenant' do
    allow(Site).to receive(:account).and_return(nil)

    expect(Hyrax::S3Migration.scope).to be_nil
  end
end
