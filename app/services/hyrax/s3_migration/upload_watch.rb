# frozen_string_literal: true

# TEMPORARY(s3-migration): copy of samvera/hyrax#7716. Remove, with every file carrying this tag, once the
# Hyrax this app pins includes that PR.
# Find them all: git grep -l 'TEMPORARY(s3-migration)'

module Hyrax
  module S3Migration
    # Remembers which objects exist under a file set's prefix before an upload. valkyrie-shrine checks the copy
    # inside upload, so an upload that fails verification has already written its object, under a key the caller
    # never receives; this finds and removes it. Only safe while FileLock keeps other jobs from uploading for the
    # same file set.
    class UploadWatch
      def initialize(s3_storage:, file_set_id:)
        shrine = s3_storage.shrine
        @bucket = shrine.bucket
        @prefix = "#{[shrine.prefix, file_set_id].compact.join('/')}/"
        @before = keys
      end

      # Removes the objects created since the snapshot. It never raises: it runs while another error is propagating.
      def discard_new
        @bucket.objects(prefix: @prefix).each { |object| object.delete unless @before.include?(object.key) }
      rescue StandardError => e
        Hyrax.logger.warn("S3Migration: could not remove objects left under #{@prefix}: #{e.class}: #{e.message}")
      end

      private

      def keys
        @bucket.objects(prefix: @prefix).map(&:key)
      end
    end
  end
end
