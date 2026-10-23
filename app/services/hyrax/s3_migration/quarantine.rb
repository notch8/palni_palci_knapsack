# frozen_string_literal: true

# TEMPORARY(s3-migration): copy of samvera/hyrax#7717. Remove, with every file carrying this tag, once the
# Hyrax this app pins includes that PR.
# Find them all: git grep -l 'TEMPORARY(s3-migration)'

module Hyrax
  module S3Migration
    # Handles the disk copy of one manifest entry after migration: move it into <storage>/.quarantine
    # (a rename on the same volume), restore it, and later purge old quarantined files. Every action
    # is driven by manifest entries, so it is limited to the entries the manifest scope selects.
    # All actions are dry runs unless apply: true.
    class Quarantine
      DIRECTORY = '.quarantine'

      def self.base_path
        SourceStorage.base_path
      end

      # Deletes the quarantined copies of the files in the manifest, and nothing else.
      # @return [Array<Integer>] [files purged (or that would be), files too recent]
      def self.purge(apply:, min_age:, base: base_path, manifest: Manifest.new)
        raise ArgumentError, "min_age must be positive, got #{min_age.inspect}" unless min_age.to_f.positive?

        files = manifest.each_entry.filter_map { |entry| quarantine_path(entry, base) }.select { |file| File.file?(file) }
        old, recent = files.partition { |file| Time.current - File.mtime(file) >= min_age }
        old.each { |file| delete_with_empty_parents(file, base) } if apply
        [old.size, recent.size]
      end

      def self.disk_path(entry, base)
        candidate = SourceStorage.path_for(entry[:old_id])
        candidate if candidate.start_with?("#{base}/")
      end

      def self.quarantine_path(entry, base)
        path = disk_path(entry, base)
        File.join(base, DIRECTORY, path.delete_prefix("#{base}/")) if path
      end

      def self.delete_with_empty_parents(file, base)
        root = File.join(base, DIRECTORY)
        File.delete(file)
        dir = File.dirname(file)
        while dir.start_with?("#{root}/") && Dir.empty?(dir)
          Dir.rmdir(dir)
          dir = File.dirname(dir)
        end
      rescue Errno::ENOENT, Errno::ENOTEMPTY
        nil # another purge got there first
      end

      def initialize(entry, apply: false, verify_sha: true, base: nil, s3_storage: nil)
        @entry = entry
        @apply = apply
        @verify_sha = verify_sha
        @base = base || self.class.base_path
        @s3_storage = s3_storage || Valkyrie::StorageAdapter.find(:repository_s3)
      end

      # @return [Symbol] :quarantined, :already_quarantined, :disk_copy_missing, :outside_base,
      #   :database_changed or :s3_mismatch
      def quarantine
        return :outside_base unless path
        return (File.exist?(destination) ? :already_quarantined : :disk_copy_missing) unless File.exist?(path)
        return :database_changed unless current_identifier == entry[:new_id]
        return :s3_mismatch unless s3_matches_manifest?

        quarantine_file if apply
        :quarantined
      end

      # Puts the disk copy and the original identifier back, then removes the S3 upload and manifest entry
      # nothing refers to any more. The disk copy is checked against the manifest first.
      # @return [Symbol] :rolled_back, :skipped, :disk_copy_gone, :disk_copy_mismatch or :outside_base
      def rollback
        return :outside_base unless path
        return :skipped unless current_identifier == entry[:new_id]
        return :disk_copy_gone unless File.exist?(path) || File.exist?(destination)
        return :disk_copy_mismatch unless disk_copy_matches_manifest?

        restore if apply
        :rolled_back
      end

      private

      attr_reader :entry, :apply, :verify_sha, :base, :s3_storage

      def manifest
        @manifest ||= Manifest.new(storage: s3_storage)
      end

      def path
        self.class.disk_path(entry, base)
      end

      def destination
        self.class.quarantine_path(entry, base)
      end

      def current
        @current ||= Hyrax.query_service.find_by(id: entry[:file_metadata_id])
      end

      def current_identifier
        current.file_identifier.to_s
      end

      def s3_matches_manifest?
        s3_file = s3_storage.find_by(id: entry[:new_id])
        return false unless s3_file.size.to_i == entry[:size]

        !verify_sha || s3_file.checksum(digests: [Digest::SHA256.new]).first == entry[:sha256]
      end

      def disk_copy_matches_manifest?
        file = File.exist?(path) ? path : destination
        File.size(file) == entry[:size] && (!verify_sha || Digest::SHA256.file(file).hexdigest == entry[:sha256])
      end

      def quarantine_file
        FileUtils.touch(path) # a rename keeps the old mtime, which purge reads as the time quarantined
        move(path, destination)
      end

      def move(from, to)
        FileUtils.mkdir_p(File.dirname(to))
        FileUtils.mv(from, to)
      end

      def restore
        move(destination, path) unless File.exist?(path)
        current.file_identifier = Valkyrie::ID.new(entry[:old_id])
        Hyrax.persister.save(resource: current)
        discard_upload
      end

      # The rollback has already succeeded, so a failure here only leaves an unused upload behind.
      def discard_upload
        UploadCleanup.new(file_set_id: entry[:file_set_id], file_metadata_id: entry[:file_metadata_id], s3_storage:, manifest:).call(entry[:new_id])
      rescue StandardError => e
        Hyrax.logger.warn("S3Migration: rolled back #{entry[:file_set_id]} but could not remove #{entry[:new_id]}: #{e.class}: #{e.message}")
      end
    end
  end
end
