# frozen_string_literal: true

# TEMPORARY(s3-migration): copy of samvera/hyrax#7716. Remove, with every file carrying this tag, once the
# Hyrax this app pins includes that PR.
# Find them all: git grep -l 'TEMPORARY(s3-migration)'

RSpec.describe Hyrax::S3Migration::FileLock do
  let(:manager) { instance_double(Hyrax::LockManager) }

  before do
    allow(Hyrax::LockManager).to receive(:new).and_return(manager)
    allow(manager).to receive(:lock) { |_key, &block| block.call }
  end

  it 'runs the block under a lock named for the file set' do
    expect(described_class.synchronize('fs1') { :done }).to eq :done
    expect(manager).to have_received(:lock).with('s3_migration:fs1')
  end

  it 'holds the lock for 15 minutes unless told otherwise, using Hyrax retry settings' do
    described_class.synchronize('fs1') { nil }

    expect(Hyrax::LockManager).to have_received(:new).with(900_000, Hyrax.config.lock_retry_count,
                                                           Hyrax.config.lock_retry_delay)
  end

  it 'takes the time to live from S3_MIGRATION_LOCK_TTL, in seconds' do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('S3_MIGRATION_LOCK_TTL', 900).and_return('3600')

    described_class.synchronize('fs1') { nil }

    expect(Hyrax::LockManager).to have_received(:new).with(3_600_000, anything, anything)
  end
end
