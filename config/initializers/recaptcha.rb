Recaptcha.configure do |config|
  config.site_key   = YiffyAPI.config.recaptcha_site_key
  config.secret_key = YiffyAPI.config.recaptcha_secret_key
  # config.proxy = "http://example.com"
end
