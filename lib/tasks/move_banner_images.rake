# frozen_string_literal: true

# @see https://github.com/notch8/palni-palci/issues/674
# rubocop:disable Metrics/BlockLength
namespace :hyku do
  desc 'Move all banner images to new expected location'
  task copy_banner_images: :environment do
    files_in_old_location = `find #{Rails.root}/public/uploads/*/site/banner_image/ -type f`.split("\n")
    # The `1` in this path is the Site ID. Since Sites are tenant-specific,
    # and since every tenant only has one Site, every Site ID is guaranteed to be 1.
    new_location = Rails.root.join('public', 'system', 'banner_images', '1', 'original')

    grouped_file_paths = files_in_old_location.group_by do |file_path|
      File.basename(file_path)
    end
    duplicate_file_paths = grouped_file_paths.values.select { |paths| paths.size > 1 }.flatten

    FileUtils.mkdir_p(new_location)
    files_in_old_location.each do |file|
      if duplicate_file_paths.include?(file)
        tenant_uuid = file.split('/')[6]
        new_filename = "#{File.basename(file, '.*')}_#{tenant_uuid}#{File.extname(file)}"
        renamed_destination = File.join(new_location, new_filename)

        puts "#{File.basename(file)} renamed to #{File.basename(renamed_destination)}"
        puts "Copying #{file} to #{renamed_destination}"
        FileUtils.cp(file, renamed_destination)

        # Since the filename has changed, we need to "re-upload" the file to the site;
        # we can't simply point it to the new path
        Apartment::Tenant.switch(tenant_uuid) do
          site = Site.instance
          File.open(renamed_destination) { |banner_image| site.banner_image = banner_image }
          site.save!
        end
      else
        puts "Copying #{file} to #{new_location}"
        FileUtils.cp(file, new_location)
      end
    end
  end

  desc 'Delete all banner images in old location'
  task delete_old_banner_images: :environment do
    copy_first_msg = 'WARNING - before running this, run hyku:copy_banner_images and verify the ' \
                     'files get copied successfully. Continue? (y/n)'
    STDOUT.puts copy_first_msg
    conf1 = STDIN.gets.chomp
    unless %w[y yes].include?(conf1)
      puts 'Task canceled'
      exit 1
    end

    files_in_old_location = `find #{Rails.root}/public/uploads/*/site/banner_image/ -type f`.split("\n")
    files_in_new_location = `find #{Rails.root}/public/system/banner_images/*/original/ -type f`.split("\n")

    if files_in_old_location.length > files_in_new_location.length
      warning = "WARNING - more files exist in the old file location (#{files_in_old_location.length}) " \
                "than the new location (#{files_in_new_location.length}). Continue? (y/n)"
      STDOUT.puts warning
      conf2 = STDIN.gets.chomp
      unless %w[y yes].include?(conf2)
        puts 'Task canceled'
        exit 1
      end
    end

    files_in_old_location.each do |file|
      puts "Deleting #{file}"
      FileUtils.rm(file)
    end
  end
end
