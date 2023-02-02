require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
# require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
# require "action_mailbox/engine"
# require "action_text/engine"
require "action_view/railtie"
# require "action_cable/engine"
require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

require_relative "yiffyapi_default_config"
require_relative "yiffyapi_local_config"

require 'elasticsearch/rails/instrumentation'

module YiffyAPI
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.0
    config.active_record.schema_format = :sql
    config.log_tags = [->(req) {"PID:#{Process.pid}"}]
    config.action_controller.action_on_unpermitted_parameters = :raise
    config.force_ssl = true
    config.active_job.queue_adapter = :sidekiq

    if Rails.env.production? && YiffyAPI.config.ssl_options.present?
      config.ssl_options = YiffyAPI.config.ssl_options
    else
      config.ssl_options = {
        hsts: false,
        secure_cookies: false,
        redirect: { exclude: ->(request) { true } }
      }
    end

    if File.exist?("#{config.root}/REVISION")
      config.x.git_hash = File.read("#{config.root}/REVISION").strip
    elsif system("type git > /dev/null && git rev-parse --show-toplevel > /dev/null")
      config.x.git_hash = %x(git rev-parse --short HEAD).strip
    else
      config.x.git_hash = nil
    end

    config.after_initialize do
      Rails.application.routes.default_url_options = {
        host: YiffyAPI.config.hostname,
      }
    end

    config.i18n.enforce_available_locales = false

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
  end
end
