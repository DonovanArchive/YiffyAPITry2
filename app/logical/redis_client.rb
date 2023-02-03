class RedisClient

  def self.client
    @client ||= ::Redis.new(url: YiffyAPI.config.redis_url)
  end
end
