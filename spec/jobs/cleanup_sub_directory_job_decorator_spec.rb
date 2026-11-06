# frozen_string_literal: true

RSpec.describe CleanupSubDirectoryJob do
  let(:root) { Pathname.new(Dir.mktmpdir) }
  let(:directory) { root.join('hyrax', 'uploaded_file', 'file') }
  let(:old) { Time.zone.now - 60.days }
  let(:recent) { Time.zone.now - 1.day }

  def make_file(relative, mtime:, content: 'abcd')
    path = directory.join(relative)
    FileUtils.mkdir_p(path.dirname)
    File.write(path, content)
    File.utime(mtime, mtime, path)
    path
  end

  def run(**options)
    job = described_class.new
    job.perform(delete_ingested_after_days: 30, delete_all_after_days: 30, directory: directory.to_s, **options)
    job
  end

  after { FileUtils.remove_entry(root) }

  context 'with the CarrierWave cache layout (<id>/<cache id>/<file>)' do
    let!(:stale) { make_file('7/1708639922-1-0438-8067/photo.jpg', mtime: old) }
    let!(:fresh) { make_file('8/1793000000-1-0001-0001/photo.jpg', mtime: recent) }

    it 'deletes files older than the cutoff and keeps newer ones' do
      run

      expect(stale).not_to exist
      expect(fresh).to exist
    end

    it 'removes the cache and upload directories it emptied' do
      run

      expect(directory.join('7')).not_to exist
      expect(directory.join('8')).to exist
    end

    it 'counts the files and bytes it deleted' do
      job = run

      expect(job.files_deleted).to eq 1
      expect(job.bytes_deleted).to eq 4
    end
  end

  context 'with the stored layout (<id>/<file>)' do
    let!(:stale) { make_file('9/document.pdf', mtime: old) }

    it 'still deletes old files' do
      run

      expect(stale).not_to exist
    end
  end

  context 'with dry_run: true' do
    let!(:stale) { make_file('7/1708639922-1-0438-8067/photo.jpg', mtime: old) }

    it 'deletes nothing and keeps the directories' do
      run(dry_run: true)

      expect(stale).to exist
    end

    it 'reports what it would delete' do
      job = run(dry_run: true)

      expect(job.files_deleted).to eq 1
      expect(job.bytes_deleted).to eq 4
    end
  end
end
