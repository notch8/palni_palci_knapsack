# frozen_string_literal: true

# TEMPORARY(s3-migration): copy of samvera/hyrax#7716. Remove, with every file carrying this tag, once the
# Hyrax this app pins includes that PR.
# Find them all: git grep -l 'TEMPORARY(s3-migration)'

module Hyrax
  module S3Migration
    # Removes an upload the database does not point at, along with the manifest entry that names it.
    class UploadCleanup
      def initialize(file_set_id:, file_metadata_id:, s3_storage:, manifest:)
        @file_set_id = file_set_id.to_s
        @file_metadata_id = file_metadata_id
        @s3_storage = s3_storage
        @manifest = manifest
      end

      # The save can raise after committing (a timeout, say), so the database decides, not the exception.
      # @param upload_id [Valkyrie::ID, String] the S3 identifier to discard
      def call(upload_id)
        upload_id = Valkyrie::ID.new(upload_id.to_s)
        return if referenced?(upload_id)

        s3_storage.delete(id: upload_id)
        forget_entry(upload_id)
      end

      private

      attr_reader :file_set_id, :file_metadata_id, :s3_storage, :manifest

      # When the database cannot be read, keep the upload: the manifest entry still points at it.
      def referenced?(upload_id)
        Hyrax.query_service.find_by(id: file_metadata_id).file_identifier == upload_id
      rescue StandardError
        true
      end

      # Only an entry naming this upload goes; another process's entry for the file set stays. Failing here
      # must not hide the error that sent the migration to cleanup.
      def forget_entry(upload_id)
        manifest.delete(file_set_id) if manifest.read(file_set_id)&.dig(:new_id) == upload_id.to_s
      rescue StandardError => e
        Hyrax.logger.warn("S3Migration: could not remove the manifest entry for #{file_set_id}: #{e.class}: #{e.message}")
      end
    end
  end
end
