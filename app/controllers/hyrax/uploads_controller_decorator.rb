# frozen_string_literal: true

# OVERRIDE Hyrax v5.0.4 to fix a race condition in chunked uploads for multi-pod environments with a shared file system.
# To prevent file corruption from stale cache reads, the file size is now read directly from the file handle to ensure an accurate size check.
module Hyrax
  module UploadsControllerDecorator
    private

    def handle_chunk(content_range, chunk)
      file_path = @upload.file.path

      # In a multi-pod environment with a shared filesystem (like NFS), attribute
      # caching can cause `File.size` to return a stale value. Opening the file
      # for reading forces a metadata refresh, ensuring we get the correct size
      # without reading the entire file into memory.
      current_size = 0
      File.open(file_path, "r") { |f| current_size = f.size } if file_path && File.exist?(file_path)

      begin_of_chunk = content_range[/\ (.*?)-/, 1].to_i

      if @upload.file.present? && begin_of_chunk == current_size
        File.open(file_path, "ab") do |f|
          f.write(chunk.read)
          f.fsync
        end
      else
        @upload.file = chunk
      end
    end
  end
end

Hyrax::UploadsController.prepend(Hyrax::UploadsControllerDecorator)
