# frozen_string_literal: true

# TEMPORARY(s3-migration): remove once the Hyku pin includes samvera/hyku#3393 (then use tenantize:task
# instead), together with every other file carrying this tag.
# Find them all: git grep -l 'TEMPORARY(s3-migration)'

RSpec.describe Hyku::S3Migration::Tenants do
  let(:accounts) { [account('one'), account('search'), account('two')] }
  let(:relation) { double('relation') }
  let(:switched) { [] }
  let(:seen) { [] }

  def account(name)
    double(name, name:, cname: "#{name}.example.com", tenant: "#{name}-schema")
  end

  before do
    allow(relation).to receive(:find_each) { |&block| accounts.each(&block) }
    allow(Account).to receive_messages(all: relation, where: relation)
    allow(Apartment::Tenant).to receive(:switch) do |tenant, &block|
      switched << tenant
      block.call
    end
  end

  it 'visits every tenant except the search account' do
    visited = []

    described_class.each { |acct| visited << acct.cname }

    expect(visited).to eq %w[one.example.com two.example.com]
  end

  it 'switches into each tenant with Apartment' do
    described_class.each { |acct| seen << acct.cname }

    expect(switched).to eq %w[one-schema two-schema]
  end

  it 'limits to the given tenants' do
    described_class.each(tenants: ['one.example.com']) { |acct| seen << acct.cname }

    expect(Account).to have_received(:where).with(cname: ['one.example.com'])
  end

  it 'prefers the account model\'s own search-only flag when it has one' do
    flagged = double('flagged', name: 'x', cname: 'x.example.com', tenant: 'x-schema', search_only?: true)
    allow(relation).to receive(:find_each) { |&block| [flagged].each(&block) }
    visited = []

    described_class.each { |acct| visited << acct.cname }

    expect(visited).to be_empty
  end

  it 'reports a failing tenant and carries on with the rest' do
    errors = []
    visited = []

    failed = described_class.each(on_error: ->(acct, error) { errors << [acct.cname, error.message] }) do |acct|
      raise 'boom' if acct.name == 'one'

      visited << acct.cname
    end

    expect(failed).to eq ['one.example.com']
    expect(errors).to eq [['one.example.com', 'boom']]
    expect(visited).to eq ['two.example.com']
  end
end
