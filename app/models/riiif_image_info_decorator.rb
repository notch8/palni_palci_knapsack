# frozen_string_literal: true

# Hyku's riiif info service reports the stored width/height from Solr, which ignore EXIF orientation.
# With autorotate on, swap them for tags that turn the image 90/270 degrees so they match the tiles.
module RiiifImageInfoDecorator
  AXIS_SWAPPING_ORIENTATIONS = [5, 6, 7, 8].freeze

  def info
    @oriented_info ||= orient(super)
  end

  private

  def orient(info)
    return info unless Riiif.autorotate? && Riiif.use_vips? && axes_swapped?

    Riiif::ImageInformation.new(width: info.height, height: info.width, format: info.format, channels: info.channels)
  end

  def axes_swapped?
    image = Vips::Image.new_from_file(file.path.to_s)
    image.get_typeof('orientation').positive? && AXIS_SWAPPING_ORIENTATIONS.include?(image.get('orientation'))
  end
end

Riiif::Image.prepend(RiiifImageInfoDecorator)
