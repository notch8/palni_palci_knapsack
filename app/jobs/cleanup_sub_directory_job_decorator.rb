# frozen_string_literal: true

# OVERRIDE: also clean the CarrierWave cache layout (<id>/<cache id>/<file>) and add a dry run.
module CleanupSubDirectoryJobDecorator
  attr_reader :bytes_deleted

  def perform(dry_run: false, **)
    @dry_run = dry_run
    @bytes_deleted = 0
    super(**)
    logger.info("Dry run: would delete #{files_deleted} files (#{bytes_deleted} bytes)") if @dry_run
  end

  private

  def process_upload_dir(upload_dir, uploaded_file_id)
    Dir.glob("#{upload_dir}/*").each do |path|
      if File.directory?(path)
        process_upload_dir(path, uploaded_file_id)
      elsif File.file?(path) && should_be_deleted?(path, uploaded_file_id)
        remove(path)
      end
    end
  end

  def remove(path)
    @bytes_deleted += File.size?(path).to_i
    File.delete(path) unless @dry_run
    @files_deleted += 1
    logger.info("Checked #{@files_checked}, deleted #{@files_deleted} files") if (@files_deleted % 100).zero?
  end

  def delete_empty_directories
    return if @dry_run

    Dir.glob("#{directory}/*/*").select { |path| File.directory?(path) }.each do |dir|
      FileUtils.rmdir(dir)
    rescue Errno::ENOTEMPTY
      next
    end
    super
  end
end

CleanupSubDirectoryJob.prepend(CleanupSubDirectoryJobDecorator)
