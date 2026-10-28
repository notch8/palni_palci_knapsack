# frozen_string_literal: true

RSpec.describe Hyku::EachTenant do
  let(:accounts) { [account('one'), account('search'), account('two')] }
  let(:relation) { double('relation') }
  let(:switched) { [] }
  let(:seen) { [] }

  def account(name)
    double(name, name:, cname: "#{name}.example.com", tenant: "#{name}-schema")
  end

  before do
    allow(relation).to receive(:find_each) { |&block| accounts.each(&block) }
    allow(Account).to receive_messages(all: relation, tenants: relation)
    allow(Apartment::Tenant).to receive(:switch) do |tenant, &block|
      switched << tenant
      block.call
    end
  end

  it 'visits every tenant except the search account' do
    visited = []

    described_class.call { |acct| visited << acct.cname }

    expect(visited).to eq %w[one.example.com two.example.com]
  end

  it 'switches into each tenant with Apartment' do
    described_class.call { |acct| seen << acct.cname }

    expect(switched).to eq %w[one-schema two-schema]
  end

  it 'limits to the given tenants' do
    described_class.call(tenants: ['one.example.com']) { |acct| seen << acct.cname }

    expect(Account).to have_received(:tenants).with(['one.example.com'])
  end

  context 'when tenants are required' do
    it 'refuses to run on every tenant' do
      expect { described_class.call(require_tenants: true) { |acct| seen << acct.cname } }
        .to raise_error(described_class::TenantsRequired)
      expect(seen).to be_empty
    end

    it 'runs on the tenants it is given' do
      described_class.call(tenants: ['one.example.com'], require_tenants: true) { |acct| seen << acct.cname }

      expect(Account).to have_received(:tenants).with(['one.example.com'])
      expect(seen).not_to be_empty
    end
  end

  it 'prefers the account model\'s own search-only flag when it has one' do
    flagged = double('flagged', name: 'x', cname: 'x.example.com', tenant: 'x-schema', search_only?: true)
    allow(relation).to receive(:find_each) { |&block| [flagged].each(&block) }
    visited = []

    described_class.call { |acct| visited << acct.cname }

    expect(visited).to be_empty
  end

  it 'reports a failing tenant and carries on with the rest' do
    errors = []
    visited = []

    failed = described_class.call(on_error: ->(acct, error) { errors << [acct.cname, error.message] }) do |acct|
      raise 'boom' if acct.name == 'one'

      visited << acct.cname
    end

    expect(failed).to eq ['one.example.com']
    expect(errors).to eq [['one.example.com', 'boom']]
    expect(visited).to eq ['two.example.com']
  end
end
