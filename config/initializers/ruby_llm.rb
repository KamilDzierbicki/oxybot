# Every model call goes through LiteLLM's OpenAI-compatible API, so the app names LiteLLM aliases
# (litellm.yaml), never providers. See config/application.rb for how the URL is picked.
RubyLLM.configure do |config|
  config.openai_api_key = ENV.fetch("LITELLM_API_KEY", "sk-flint-local")
  config.openai_api_base = Rails.configuration.x.llm_url
  config.request_timeout = 60
  config.max_retries = 1
end
