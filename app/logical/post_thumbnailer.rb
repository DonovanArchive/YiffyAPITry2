module PostThumbnailer

  def self.generate_resizes(file, height, width, type)
    case type
    when :video
      video = FFMPEG::Movie.new(file.path)
      crop_file = generate_video_crop_for(video, YiffyAPI.config.small_image_width)
      preview_file = generate_video_preview_for(file.path, YiffyAPI.config.small_image_width)
      sample_file = generate_video_sample_for(file.path)
    when :image
      preview_file = DanbooruImageResizer.resize(file, YiffyAPI.config.small_image_width, YiffyAPI.config.small_image_width, 87)
      crop_file = DanbooruImageResizer.crop(file, YiffyAPI.config.small_image_width, YiffyAPI.config.small_image_width, 87)
      if width > YiffyAPI.config.large_image_width
        sample_file = DanbooruImageResizer.resize(file, YiffyAPI.config.large_image_width, height, 87)
      end
    end

    [preview_file, crop_file, sample_file]
  end

  def self.generate_thumbnail(file, type)
    case type
    when :video
      preview_file = generate_video_preview_for(file.path, YiffyAPI.config.small_image_width)
    when :image
      preview_file = DanbooruImageResizer.resize(file, YiffyAPI.config.small_image_width, YiffyAPI.config.small_image_width, 87)
    end

    preview_file
  end

  def self.generate_video_crop_for(video, width)
    vp = Tempfile.new(["video-preview", ".#{YiffyAPI.config.preview_file_type(:crop, :video)}"], binmode: true)
    video.screenshot(vp.path, { seek_time: 0, resolution: "#{video.width}x#{video.height}" })
    crop = DanbooruImageResizer.crop(vp, width, width, 87)
    vp.close
    crop
  end

  def self.generate_video_preview_for(video, width)
    output_file = Tempfile.new(["video-preview", ".#{YiffyAPI.config.preview_file_type(:preview, :video)}"], binmode: true)
    stdout, stderr, status = Open3.capture3(YiffyAPI.config.ffmpeg_path, "-y", "-i", video, "-vf", "thumbnail,scale=#{width}:-1", "-frames:v", "1", output_file.path)

    unless status == 0
      Rails.logger.warn("[FFMPEG PREVIEW STDOUT] #{stdout.chomp!}")
      Rails.logger.warn("[FFMPEG PREVIEW STDERR] #{stderr.chomp!}")
      raise CorruptFileError, "could not generate thumbnail"
    end
    output_file
  end

  def self.generate_video_sample_for(video)
    output_file = Tempfile.new(["video-sample", ".#{YiffyAPI.config.preview_file_type(:large, :video)}"], binmode: true)
    stdout, stderr, status = Open3.capture3(YiffyAPI.config.ffmpeg_path, "-y", "-i", video, "-vf", "thumbnail", "-frames:v", "1", output_file.path)

    unless status == 0
      Rails.logger.warn("[FFMPEG SAMPLE STDOUT] #{stdout.chomp!}")
      Rails.logger.warn("[FFMPEG SAMPLE STDERR] #{stderr.chomp!}")
      raise CorruptFileError, "could not generate sample"
    end
    output_file
  end
end
