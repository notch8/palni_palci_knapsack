# frozen_string_literal: true

# OVERRIDE Hyku: Valkyrie's StreamFile#disk_path copies an S3 original into Dir.tmpdir and nothing deletes it,
# so every file served through IIIF fills the pod's ephemeral storage until the pod is evicted.
module Hyrax
  module RiiifFileResolverDecorator
    TMP_COPY_PATTERN = /\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}-shrine__/
    TMP_COPY_TTL = 1.hour
    SWEEP_INTERVAL = 5.minutes
    SWEEP_LOCK = Mutex.new

    # A swept copy that is still cached is fetched again by RiiifFileResolver#find, which checks File.exist?.
    def self.sweep_tmp_copies(dir: Dir.tmpdir, now: Time.current)
      return unless SWEEP_LOCK.try_lock

      begin
        return if @last_sweep && @last_sweep > now - SWEEP_INTERVAL

        @last_sweep = now
        Dir.children(dir).grep(TMP_COPY_PATTERN).each { |name| delete_if_stale(File.join(dir, name), now) }
      ensure
        SWEEP_LOCK.unlock
      end
    end

    def self.delete_if_stale(path, now)
      File.delete(path) if File.file?(path) && File.mtime(path) < now - TMP_COPY_TTL
    rescue Errno::ENOENT
      nil
    end

    def self.reset_sweep
      @last_sweep = nil
    end

    def find(id)
      super.tap do |file|
        FileUtils.touch(file.path)
      rescue Errno::ENOENT
        nil
      end
    end

    private

    def load_file(id)
      super.tap { RiiifFileResolverDecorator.sweep_tmp_copies }
    end
  end
end

Hyrax::RiiifFileResolver.prepend(Hyrax::RiiifFileResolverDecorator)
