# frozen_string_literal: true

RSpec.describe Hyrax::RiiifFileResolverDecorator do
  let(:dir) { Dir.mktmpdir }
  let(:now) { Time.now }
  let(:uuid) { SecureRandom.uuid }
  let(:old_copy) { File.join(dir, "#{uuid}-shrine___fs1_abc") }
  let(:new_copy) { File.join(dir, "#{SecureRandom.uuid}-shrine___fs2_def") }
  let(:unrelated) { File.join(dir, "#{SecureRandom.uuid}-other___fs3_ghi") }

  before do
    described_class.reset_sweep
    [old_copy, new_copy, unrelated].each { |path| File.write(path, 'bytes') }
    File.utime(now - 2.hours, now - 2.hours, old_copy)
    File.utime(now - 2.hours, now - 2.hours, unrelated)
  end

  after { FileUtils.remove_entry(dir) }

  describe '.sweep_tmp_copies' do
    it 'deletes shrine copies older than the TTL and leaves everything else' do
      described_class.sweep_tmp_copies(dir:, now:)

      expect(File.exist?(old_copy)).to be false
      expect(File.exist?(new_copy)).to be true
      expect(File.exist?(unrelated)).to be true
    end

    it 'sweeps at most once per interval' do
      described_class.sweep_tmp_copies(dir:, now:)
      File.write(old_copy, 'bytes')
      File.utime(now - 2.hours, now - 2.hours, old_copy)

      described_class.sweep_tmp_copies(dir:, now: now + 1.minute)
      expect(File.exist?(old_copy)).to be true

      described_class.sweep_tmp_copies(dir:, now: now + 6.minutes)
      expect(File.exist?(old_copy)).to be false
    end

    it 'carries on when a file is already gone' do
      allow(File).to receive(:mtime).and_raise(Errno::ENOENT)

      expect { described_class.sweep_tmp_copies(dir:, now:) }.not_to raise_error
    end
  end

  describe '#load_file' do
    it 'returns the resolver result and sweeps' do
      resolver = Hyrax::RiiifFileResolver.new
      allow(described_class).to receive(:sweep_tmp_copies)
      file_set = double('file_set')
      file = double('file', disk_path: Pathname.new('/tmp/x'))
      allow(Hyrax.query_service).to receive(:find_by).with(id: 'fs1').and_return(file_set)
      allow(Hyrax.custom_queries).to receive(:find_original_file).with(file_set:).and_return(double(file:))

      expect(resolver.send(:load_file, 'fs1/files/abc')).to eq '/tmp/x'
      expect(described_class).to have_received(:sweep_tmp_copies)
    end
  end
end
