# frozen_string_literal: true

# Site.instance (upstream Hyku, hyrax-webapp/app/models/site.rb) is defined
# as `first_or_create`, with no memoization -- every call is a fresh
# database round-trip. Profiling a single /catalog page load found
# Site.instance called ~650-680 times, almost entirely through the
# `delegate :account, ..., to: :instance` line, i.e. via the ubiquitous
# `Site.account` convenience accessor -- not through any one obvious N+1
# loop. This decorator memoizes it per-request via RequestStore (already a
# transitive dependency here), the same way `current_account` already is
# in ApplicationController/HykuHelper.
RSpec.describe Site, type: :model do
  before { RequestStore.clear! }
  after { RequestStore.clear! }

  describe '.instance' do
    context 'on a specific tenant' do
      it 'only queries the database once across multiple calls in the same request' do
        expect(Site).to receive(:first_or_create).once.and_call_original

        3.times { Site.instance }
      end

      it 'returns the same object across multiple calls' do
        first = Site.instance
        second = Site.instance

        expect(first).to equal(second)
      end

      it 'queries again after RequestStore is cleared (simulating a new request)' do
        Site.instance
        RequestStore.clear!

        expect(Site).to receive(:first_or_create).once.and_call_original
        Site.instance
      end
    end

    context 'on global tenant' do
      before do
        allow(Account).to receive(:global_tenant?).and_return true
      end

      it 'is still a NilSite (memoization does not change the existing global-tenant branch)' do
        expect(Site.instance).to eq(NilSite.instance)
      end
    end
  end
end
