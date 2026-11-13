# Every model call goes through LiteLLM's OpenAI-compatible API, so the app names LiteLLM aliases
# (litellm.yaml), never providers. See config/application.rb for how the URL is picked.
RubyLLM.configure do |config|
  config.openai_api_key = ENV.fetch("LITELLM_API_KEY", "sk-oxybot-local")
  config.openai_api_base = Rails.configuration.x.llm_url
  # Instructions go as "system", which every provider behind LiteLLM accepts (RubyLLM defaults to OpenAI's "developer")
  config.openai_use_system_role = true
  config.request_timeout = 60
  config.max_retries = 1
end
