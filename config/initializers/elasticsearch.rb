Elasticsearch::Model.client = Elasticsearch::Client.new host: YiffyAPI.config.elasticsearch_host
Rails.configuration.to_prepare do
  Elasticsearch::Model::Response::Response.include(YiffyAPI::Paginator::ElasticsearchExtensions)
end
