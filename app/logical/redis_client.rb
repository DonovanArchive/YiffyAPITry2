class RedisClient
  module_function

  def client
    @client ||= ::Redis.new(url: YiffyAPI.config.redis_url)
  end
end
