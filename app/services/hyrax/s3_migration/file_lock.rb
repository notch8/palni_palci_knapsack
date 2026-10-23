# frozen_string_literal: true

# TEMPORARY(s3-migration): copy of samvera/hyrax#7716. Remove, with every file carrying this tag, once the
# Hyrax this app pins includes that PR.
# Find them all: git grep -l 'TEMPORARY(s3-migration)'

module Hyrax
  module S3Migration
    # Holds a lock on one file set while a block runs, so two jobs never migrate it at the same time (a double
    # enqueue, or a retry while the first attempt is still running). It is the Redis lock Hyrax takes for works.
    # A job that cannot get the lock in time raises Hyrax::LockManager::UnableToAcquireLockError and is retried.
    module FileLock
      DEFAULT_TTL_SECONDS = 900

      def self.synchronize(file_set_id, &)
        manager.lock("s3_migration:#{file_set_id}", &)
      end

      # The lock expires on its own if a worker dies holding it. S3_MIGRATION_LOCK_TTL (seconds) must exceed the
      # time to upload the largest original.
      def self.manager
        ttl = ENV.fetch('S3_MIGRATION_LOCK_TTL', DEFAULT_TTL_SECONDS).to_i * 1000
        Hyrax::LockManager.new(ttl, Hyrax.config.lock_retry_count, Hyrax.config.lock_retry_delay)
      end
    end
  end
end
