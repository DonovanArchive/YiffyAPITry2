class StorageManager::Match < StorageManager
  def initialize
    @managers = []

    yield self if block_given?
  end

  def add_manager(constraints)
    manager = yield
    @managers << [constraints, manager]
  end

  def find(params)
    @managers.each do |constraints, manager|
      match = true

      if params[:id] && constraints[:id] && !constraints[:id].include?(params[:id].to_i)
        match = false
      end

      if constraints[:id] && !params[:id]
        match = false
      end

      if params[:type] && constraints[:type]
        if constraints[:type].respond_to?(:include?)
          if !constraints[:type].include?(params[:type])
            match = false
          end
        elsif constraints[:type] != params[:type]
          match = false
        end
      end

      if constraints[:type] && !params[:type]
        match = false
      end

      if match
        if block_given?
          return yield(manager)
        else
          return manager
        end
      end
    end
  end

  def store_file(io, post, type)
    find(id: post.id, type: type) do |manager|
      manager.store_file(io, post, type)
    end
  end

  def delete_file(post_id, md5, file_ext, type)
    find(id: post_id, type: type) do |manager|
      manager.delete_file(post_id, md5, file_ext, type)
    end
  end

  def open_file(post, type)
    find(id: post.id, type: type) do |manager|
      manager.open_file(post, type)
    end
  end

  def file_url(post, type, **options)
    find(id: post.id, type: type) do |manager|
      manager.file_url(post, type, **options)
    end
  end

  def file_path(post, file_ext, type, **options)
    find(id: post.id, type: type) do |manager|
      manager.file_path(post, file_ext, type, **options)
    end
  end
end
