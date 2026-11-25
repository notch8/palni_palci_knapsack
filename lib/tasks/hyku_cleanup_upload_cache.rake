# frozen_string_literal: true

namespace :hyku do
  desc <<~DESC
    Delete CarrierWave upload-cache files (<cache path>/hyrax/uploaded_file/file) older than AGE_DAYS.

    The cache path is shared by every tenant, so age is the only test. Cached copies are only needed
    while an upload is being saved; the stored copy lives under the tenant's uploads path.

      AGE_DAYS   Delete files older than N days (default: 30)
      DRY_RUN    Set to "true" to count what would be deleted without deleting it (default: false)

    Example: DRY_RUN=true AGE_DAYS=30 bin/rails hyku:cleanup_upload_cache
  DESC
  task cleanup_upload_cache: :environment do
    age_days = Integer(ENV.fetch('AGE_DAYS', '30'), exception: false)
    abort 'AGE_DAYS must be a positive whole number.' unless age_days&.positive?

    directory = File.join(Hyrax.config.cache_path.call.to_s, CleanupUploadFilesJob::CARRIERWAVE_SUBDIR)
    abort "No upload cache at #{directory}." unless Dir.exist?(directory)

    dry_run = ActiveModel::Type::Boolean.new.cast(ENV.fetch('DRY_RUN', 'false'))
    job = CleanupSubDirectoryJob.new
    job.perform(delete_ingested_after_days: age_days, delete_all_after_days: age_days,
                directory:, dry_run:)

    puts "#{dry_run ? 'Would delete' : 'Deleted'} #{job.files_deleted} files " \
         "(#{(job.bytes_deleted / 2.0**30).round(2)} GiB) older than #{age_days} days in #{directory}"
  end
end
