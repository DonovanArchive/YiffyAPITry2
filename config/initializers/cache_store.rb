def get_cache_store
  if Rails.env.test?
    [:memory_store, { size: 32.megabytes }]
  elsif YiffyAPI.config.disable_cache_store?
    :null_store
  else
    [:mem_cache_store, YiffyAPI.config.memcached_servers, { namespace: YiffyAPI.config.safe_app_name }]
  end
end

Rails.application.configure do
  begin
    config.cache_store = get_cache_store
    config.action_controller.cache_store = get_cache_store
    Rails.cache = ActiveSupport::Cache.lookup_store(Rails.application.config.cache_store)
  end
end
