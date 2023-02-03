class IqdbProxy
  module_function

  class Error < StandardError; end

  def query(image_url)
    raise NotImplementedError if YiffyAPI.config.iqdbs_server.blank?

    url = URI.parse(YiffyAPI.config.iqdbs_server)
    url.path = "/similar"
    url.query = { url: image_url }.to_query
    json = HTTParty.get(url.to_s, YiffyAPI.config.httparty_options)
    return [] if json.code != 200
    decorate_posts(json.parsed_response)
  end

  def query_file(image)
    raise NotImplementedError if YiffyAPI.config.iqdbs_server.blank?

    url = URI.parse(YiffyAPI.config.iqdbs_server)
    url.path = "/similar"
    json = HTTParty.post(url.to_s, body: {
      file: image,
    }.merge(YiffyAPI.config.httparty_options))
    return [] if json.code != 200
    decorate_posts(json.parsed_response)
  end

  def query_path(image_path)
    raise NotImplementedError if YiffyAPI.config.iqdbs_server.blank?

    f = File.open(image_path)
    url = URI.parse(YiffyAPI.config.iqdbs_server)
    url.path = "/similar"
    json = HTTParty.post(url.to_s, body: {
      file: f,
    }.merge(YiffyAPI.config.httparty_options))
    f.close
    return [] if json.code != 200
    decorate_posts(json.parsed_response)
  end

  def decorate_posts(json)
    raise Error, "Server returned an error. Most likely the url is not found." unless json.is_a?(Array)
    json.map do |x|
      x["post"] = Post.find(x["post_id"])
      x
    rescue ActiveRecord::RecordNotFound
      nil
    end.compact
  end
end
