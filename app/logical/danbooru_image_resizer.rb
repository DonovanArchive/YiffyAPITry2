module DanbooruImageResizer

  # Taken from ArgyllCMS 2.0.0 (see also: https://ninedegreesbelow.com/photography/srgb-profile-comparison.html)
  SRGB_PROFILE = Rails.root.join("config/sRGB.icm").to_s.freeze
  # https://www.libvips.org/API/current/libvips-resample.html#vips-thumbnail
  THUMBNAIL_OPTIONS = { size: :down, linear: false, no_rotate: true, export_profile: SRGB_PROFILE, import_profile: SRGB_PROFILE }.freeze
  # https://www.libvips.org/API/current/VipsForeignSave.html#vips-jpegsave
  JPEG_OPTIONS = { background: 0, strip: true, interlace: true, optimize_coding: true }.freeze
  CROP_OPTIONS = { linear: false, no_rotate: true, export_profile: SRGB_PROFILE, import_profile: SRGB_PROFILE, crop: :attention }.freeze

  def self.resize(file, width, height, resize_quality = 90)
    output_file = Tempfile.new
    resized_image = thumbnail(file, width, height, THUMBNAIL_OPTIONS)
    resized_image.jpegsave(output_file.path, Q: resize_quality, **JPEG_OPTIONS)

    output_file
  end

  def self.crop(file, width, height, resize_quality = 90)
    return nil unless YiffyAPI.config.enable_image_cropping?

    output_file = Tempfile.new
    resized_image = thumbnail(file, width, height, CROP_OPTIONS)
    resized_image.jpegsave(output_file.path, Q: resize_quality, **JPEG_OPTIONS)

    output_file
  end

  # https://github.com/libvips/libvips/wiki/HOWTO----Image-shrinking
  # https://www.libvips.org/API/current/Using-vipsthumbnail.md.html
  def self.thumbnail(file, width, height, options)
    Vips::Image.thumbnail(file.path, width, height: height, **options)
  rescue Vips::Error => e
    raise e unless e.message =~ /icc_transform/i
    Vips::Image.thumbnail(file.path, width, height: height, **options.except(:import_profile))
  end
end
