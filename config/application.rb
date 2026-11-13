require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module OpenSpark
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Where RubyLLM sends model calls. With LITELLM_URL set they go to LiteLLM; without it, development uses
    # the MockLlm mounted in this app (port from bin/dev) and tests use a WebMock host routed to the same Rack app.
    config.x.mock_llm = ENV["LITELLM_URL"].blank?
    config.x.llm_url = ENV["LITELLM_URL"].presence ||
      (Rails.env.test? ? "http://mock-llm.test/v1" : "http://localhost:#{ENV.fetch("PORT", 3120)}/mock_llm/v1")

    # Absolute links outside a request, e.g. citations in Slack replies
    config.x.url_options = { host: ENV.fetch("APP_HOST", "localhost:3120"), protocol: ENV.fetch("APP_PROTOCOL", "http") }
  end
end
