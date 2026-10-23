# frozen_string_literal: true

# TEMPORARY(s3-migration): copy of samvera/hyrax#7716. Remove, with every file carrying this tag, once the
# Hyrax this app pins includes that PR.
# Find them all: git grep -l 'TEMPORARY(s3-migration)'

RSpec.describe Hyrax::S3Migration::UploadWatch do
  subject(:watch) { described_class.new(s3_storage:, file_set_id: 'fs1') }

  let(:existing) { double('existing', key: 'fs1/old', delete: nil) }
  let(:stray) { double('stray', key: 'fs1/new', delete: nil) }
  let(:listed) { [existing] }
  let(:bucket) { double('bucket') }
  let(:shrine) { double('shrine', bucket:, prefix: nil) }
  let(:s3_storage) { double('s3 storage', shrine:) }

  before { allow(bucket).to receive(:objects).with(prefix: 'fs1/') { listed } }

  it 'removes only the objects that appeared after it was created' do
    watch
    listed << stray

    watch.discard_new

    expect(stray).to have_received(:delete)
    expect(existing).not_to have_received(:delete)
  end

  it 'looks under the storage prefix when there is one' do
    allow(shrine).to receive(:prefix).and_return('repo')
    allow(bucket).to receive(:objects).with(prefix: 'repo/fs1/') { listed }

    described_class.new(s3_storage:, file_set_id: 'fs1').discard_new

    expect(bucket).to have_received(:objects).with(prefix: 'repo/fs1/').twice
  end

  it 'never raises, so it cannot hide the error that sent it here' do
    watch
    allow(bucket).to receive(:objects).and_raise('s3 down')
    allow(Hyrax.logger).to receive(:warn)

    expect { watch.discard_new }.not_to raise_error
    expect(Hyrax.logger).to have_received(:warn).with(%r{left under fs1/: RuntimeError: s3 down})
  end
end
