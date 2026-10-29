# frozen_string_literal: true

require 'rails_helper'
require 'rake'

RSpec.describe 'hyku:cleanup_upload_cache' do
  let(:task_name) { 'hyku:cleanup_upload_cache' }
  let(:cache_root) { Pathname.new(Dir.mktmpdir) }
  let(:directory) { cache_root.join('hyrax', 'uploaded_file', 'file') }
  let(:stale) { directory.join('7', '1708639922-1-0438-8067', 'photo.jpg') }

  before do
    Rake.application.rake_require 'tasks/hyku_cleanup_upload_cache' unless Rake::Task.task_defined?(task_name)
    Rake::Task.define_task(:environment) unless Rake::Task.task_defined?(:environment)
    allow(Hyrax.config).to receive(:cache_path).and_return(-> { cache_root })
    FileUtils.mkdir_p(stale.dirname)
    File.write(stale, 'abcd')
    File.utime(60.days.ago, 60.days.ago, stale)
    Rake::Task[task_name].reenable
  end

  after { FileUtils.remove_entry(cache_root) }

  def invoke(env = {})
    allow(ENV).to receive(:fetch).and_call_original
    env.each { |name, value| allow(ENV).to receive(:fetch).with(name, anything).and_return(value) }
    Rake::Task[task_name].invoke
  end

  it 'deletes files older than AGE_DAYS and reports them' do
    expect { invoke }.to output(/Deleted 1 files/).to_stdout
    expect(stale).not_to exist
  end

  it 'keeps everything on a dry run' do
    expect { invoke('DRY_RUN' => 'true') }.to output(/Would delete 1 files/).to_stdout
    expect(stale).to exist
  end

  it 'aborts on a bad AGE_DAYS' do
    expect { invoke('AGE_DAYS' => '0') }.to raise_error(SystemExit).and output(/AGE_DAYS/).to_stderr
  end

  it 'aborts when there is no cache directory' do
    FileUtils.rm_rf(directory)
    expect { invoke }.to raise_error(SystemExit).and output(/No upload cache/).to_stderr
  end
end
