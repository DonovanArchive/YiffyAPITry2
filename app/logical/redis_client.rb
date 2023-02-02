class RedisClient
  def self.client
    @@_client ||= ::Redis.new(url: YiffyAPI.config.redis_url)
  end
end
