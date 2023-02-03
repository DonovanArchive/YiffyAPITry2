class StorageManager
  class Error < StandardError; end

  DEFAULT_BASE_DIR = Rails.public_path.join("data").to_s
  IMAGE_TYPES = %i[preview large crop original].freeze
  MASCOT_PREFIX = "mascots".freeze

  attr_reader :base_url, :base_dir, :hierarchical, :large_image_prefix, :protected_prefix, :base_path, :replacement_prefix

  def initialize(
    base_url: default_base_url,
    base_path: default_base_path,
    base_dir: DEFAULT_BASE_DIR,
    hierarchical: false,
    large_image_prefix: YiffyAPI.config.large_image_prefix,
    protected_prefix: YiffyAPI.config.protected_path_prefix,
    replacement_prefix: YiffyAPI.config.replacement_path_prefix
  )
    @base_url = base_url.chomp("/")
    @base_dir = base_dir
    @base_path = base_path
    @protected_prefix = protected_prefix
    @replacement_prefix = replacement_prefix
    @hierarchical = hierarchical
    @large_image_prefix = large_image_prefix
  end

  def default_base_path
    "/data"
  end

  def default_base_url
    Rails.application.routes.url_helpers.root_url
  end

  # Store the given file at the given path. If a file already exists at that
  # location it should be overwritten atomically. Either the file is fully
  # written, or an error is raised and the original file is left unchanged. The
  # file should never be in a partially written state.
  def store(io, path)
    raise NotImplementedError, "store not implemented"
  end

  # Delete the file at the given path. If the file doesn't exist, no error
  # should be raised.
  def delete(path)
    raise NotImplementedError, "delete not implemented"
  end

  # Return a readonly copy of the file located at the given path.
  def open(path)
    raise NotImplementedError, "open not implemented"
  end

  def store_file(io, post, type)
    store(io, file_path(post.md5, post.file_ext, type))
  end

  def store_replacement(io, replacement, image_size)
    store(io, replacement_path(replacement.storage_id, replacement.file_ext, image_size))
  end

  def delete_file(_post_id, md5, file_ext, type, scale_factor: nil)
    delete(file_path(md5, file_ext, type, scale_factor: scale_factor))
    delete(file_path(md5, file_ext, type, true, scale_factor: scale_factor))
  end

  def delete_post_files(post_or_md5, file_ext)
    md5 = post_or_md5.is_a?(String) ? post_or_md5 : post_or_md5.md5
    IMAGE_TYPES.each do |type|
      delete(file_path(md5, file_ext, type, false))
      delete(file_path(md5, file_ext, type, true))
    end
    YiffyAPI.config.video_rescales.each do |k, v|
      %w[mp4 webm].each do |ext|
        delete(file_path(md5, ext, :scaled, false, scale_factor: k.to_s))
        delete(file_path(md5, ext, :scaled, true, scale_factor: k.to_s))
      end
    end
    delete(file_path(md5, "mp4", :original, false))
    delete(file_path(md5, "mp4", :original, true))
  end

  def delete_replacement(replacement)
    delete(replacement_path(replacement.storage_id, replacement.file_ext, :original))
    delete(replacement_path(replacement.storage_id, replacement.file_ext, :preview))
  end

  def open_file(post, type)
    open(file_path(post.md5, post.file_ext, type))
  end

  def move_file_delete(post)
    raise NotImplementedError, "move_file_delete not implemented"
  end

  def move_file_undelete(post)
    raise NotImplementedError, "move_file_undelete not implemented"
  end

  def protected_params(url, _post, secret: YiffyAPI.config.protected_file_secret)
    user_id = CurrentUser.id
    # ip = CurrentUser.ip_addr
    time = (Time.now + 15.minutes).to_i
    hmac = Digest::MD5.base64digest("#{time} #{url} #{user_id} #{secret}").tr("+/", "-_").gsub("==", "")
    "?auth=#{hmac}&expires=#{time}&uid=#{user_id}"
  end

  def file_url_ext(post, type, ext, scale: nil)
    subdir = subdir_for(post.md5)
    file = file_name(post.md5, ext, type, scale_factor: scale)
    base = post.protect_file? ? "#{base_path}/#{protected_prefix}" : base_path

    return "#{root_url}/images/download-preview.png" if type == :preview && !post.has_preview?
    path =
      case type
      when :preview
        "#{base}/preview/#{subdir}#{file}"
      when :crop
        "#{base}/crop/#{subdir}#{file}"
      when :scaled
        "#{base}/sample/#{subdir}#{file}"
      else
        type == :large && post.has_large? ? "#{base}/sample/#{subdir}#{file}" : "#{base}/#{subdir}#{file}"
      end
    if post.protect_file?
      "#{base_url}#{path}#{protected_params(path, post)}"
    else
      "#{base_url}#{path}"
    end
  end

  def file_url(post, type)
    file_url_ext(post, type, post.file_ext)
  end

  def replacement_url(replacement, image_size = :original)
    subdir = subdir_for(replacement.storage_id)
    file = "#{replacement.storage_id}#{'_thumb' if image_size == :preview}.#{replacement.file_ext}"
    base = "#{base_path}/#{replacement_prefix}"
    path = "#{base}/#{subdir}#{file}"
    "#{base_url}#{path}#{protected_params(path, nil, secret: YiffyAPI.config.replacement_file_secret)}"
  end

  def root_url
    origin = Addressable::URI.parse(base_url).origin
    origin = "" if origin == "null" # base_url was relative
    origin
  end

  def file_path(post_or_md5, file_ext, type, protected = false, scale_factor: nil)
    md5 = post_or_md5.is_a?(String) ? post_or_md5 : post_or_md5.md5
    subdir = subdir_for(md5)
    file = file_name(md5, file_ext, type, scale_factor: scale_factor)
    base = protected ? "#{base_dir}/#{protected_prefix}" : base_dir

    case type
    when :preview
      "#{base}/preview/#{subdir}#{file}"
    when :crop
      "#{base}/crop/#{subdir}#{file}"
    when :large
      "#{base}/sample/#{subdir}#{file}"
    when :scaled
      "#{base}/sample/#{subdir}#{file}"
    when :original
      "#{base}/#{subdir}#{file}"
    end
  end

  def file_name(md5, file_ext, type, scale_factor: nil)
    is_video = %w[mp4 webm].include?(file_ext)
    case type
    when :preview
      "#{md5}.#{YiffyAPI.config.preview_file_type(type, is_video ? :video : :image)}"
    when :crop
      "#{md5}.#{YiffyAPI.config.preview_file_type(type, is_video ? :video : :image)}"
    when :large
      "#{large_image_prefix}#{md5}.#{YiffyAPI.config.preview_file_type(type, is_video ? :video : :image)}"
    when :original
      "#{md5}.#{file_ext}"
    when :scaled
      "#{md5}_#{scale_factor}.#{file_ext}"
    end
  end

  def replacement_path(replacement_or_storage_id, file_ext, image_size)
    storage_id = replacement_or_storage_id.is_a?(String) ? replacement_or_storage_id : replacement_or_storage_id.storage_id
    subdir = subdir_for(storage_id)
    file = "#{storage_id}#{'_thumb' if image_size == :preview}.#{file_ext}"
    "#{base_dir}/#{replacement_prefix}/#{subdir}#{file}"
  end

  def store_mascot(io, mascot)
    store(io, mascot_path(mascot.md5, mascot.file_ext))
  end

  def mascot_path(md5, file_ext)
    file = "#{md5}.#{file_ext}"
    "#{base_dir}/#{MASCOT_PREFIX}/#{file}"
  end

  def mascot_url(mascot)
    file = "#{mascot.md5}.#{mascot.file_ext}"
    "#{base_url}#{base_path}/#{MASCOT_PREFIX}/#{file}"
  end

  def delete_mascot(md5, file_ext)
    delete(mascot_path(md5, file_ext))
  end

  def subdir_for(md5)
    hierarchical ? "#{md5[0..1]}/#{md5[2..3]}/" : ""
  end
end
