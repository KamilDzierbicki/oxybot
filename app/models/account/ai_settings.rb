# Per-account AI settings from the dashboard: which LiteLLM alias runs each task, the theme threshold,
# the agent's step limit and when the weekly opportunity report runs. Missing keys use DEFAULTS.
module Account::AiSettings
  extend ActiveSupport::Concern

  TASKS = {
    "extract" => "Split feedback into insights",
    "judge" => "Match insights to features",
    "assistant" => "Chat assistant (app and Slack)",
    "writer" => "Write and revise documents"
  }.freeze

  DEFAULTS = {
    "model_extract" => "oxybot-extract", "model_judge" => "oxybot-judge",
    "model_assistant" => "oxybot-assistant", "model_writer" => "oxybot-writer",
    "theme_distance" => 0.35, "agent_max_rounds" => 6,
    "weekly_report_enabled" => true, "weekly_report_day" => 1, "weekly_report_hour" => 8,
    "daily_budget_usd" => 0.0
  }.freeze

  # Valid range per numeric setting; values outside are refused, so a typo cannot disable matching
  LIMITS = {
    "theme_distance" => 0.05..0.9, "agent_max_rounds" => 1..12, "daily_budget_usd" => 0..100_000,
    "weekly_report_day" => 0..6, "weekly_report_hour" => 0..23
  }.freeze

  # Aliases LiteLLM serves (GET /v1/models), for the model pickers; the defaults when it cannot be asked
  def self.available_models
    served_models || DEFAULTS.select { |key, _| key.start_with?("model_") }.values
  end

  # The live list, or nil when LiteLLM cannot be asked (then model names cannot be checked)
  def self.served_models
    Rails.cache.fetch("litellm/models", expires_in: 10.minutes) do
      uri = URI("#{Rails.configuration.x.llm_url}/models")
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 2, read_timeout: 3) do |http|
        http.get(uri.request_uri, "Authorization" => "Bearer #{ENV.fetch("LITELLM_API_KEY", "sk-oxybot-local")}")
      end
      JSON.parse(response.body).fetch("data").map { |model| model["id"] }.sort
    end
  rescue StandardError => e
    Rails.logger.info("[ai_settings] model list unavailable: #{e.class}")
    nil
  end

  included do
    validate :ai_settings_in_range

    # Readers for forms (account.theme_distance)
    DEFAULTS.each_key { |key| define_method(key) { ai_setting(key) } }
  end

  def ai_setting(key)
    ai_settings.fetch(key.to_s) { DEFAULTS.fetch(key.to_s) }
  end

  def ai_model(task)
    ai_setting("model_#{task}")
  end

  def update_ai_settings(values)
    changes = values.to_h.stringify_keys.slice(*DEFAULTS.keys).to_h { |key, value| [ key, cast_setting(key, value) ] }
    self.ai_settings = ai_settings.merge(changes)
    unknown_models(changes).each { |task, model| errors.add(:base, "#{TASKS[task]}: LiteLLM does not serve a model called “#{model}”") }
    budget_changed = ai_settings_was["daily_budget_usd"] != ai_settings["daily_budget_usd"]
    (errors.none? && save).tap { |saved| SyncAiBudgetJob.perform_later(self) if saved && budget_changed }
  end

  # The weekly report is due in the account's chosen hour, once per week
  def opportunity_report_due?(now = Time.current)
    return false unless ai_setting("weekly_report_enabled")

    local = now.in_time_zone(time_zone)
    local.wday == ai_setting("weekly_report_day") && local.hour == ai_setting("weekly_report_hour") &&
      !documents.where(kind: "opportunity_report", created_at: local.beginning_of_week..).exists?
  end

  private

  # A misspelled alias would silently break extraction, so new model names must be ones LiteLLM serves.
  # When LiteLLM cannot be asked, names are not checked rather than blocking the save.
  def unknown_models(changes)
    served = Account::AiSettings.served_models
    return {} if served.nil?

    TASKS.keys.to_h { |task| [ task, changes["model_#{task}"] ] }
         .select { |task, model| model.present? && model != ai_settings_was["model_#{task}"] && served.exclude?(model) }
  end

  def cast_setting(key, value)
    case DEFAULTS.fetch(key)
    when true, false then ActiveModel::Type::Boolean.new.cast(value)
    when Integer then Integer(value, exception: false)
    when Float then Float(value, exception: false)
    else value.to_s.strip
    end
  end

  def ai_settings_in_range
    LIMITS.each do |key, range|
      value = ai_settings[key]
      errors.add(:ai_settings, "#{key.humanize} must be between #{range.min} and #{range.max}") if ai_settings.key?(key) && !(value.is_a?(Numeric) && range.cover?(value))
    end
    TASKS.each_key do |task|
      errors.add(:ai_settings, "Model for #{TASKS[task].downcase} cannot be empty") if ai_settings.key?("model_#{task}") && ai_settings["model_#{task}"].blank?
    end
    errors.add(:time_zone, "is not a known time zone") unless ActiveSupport::TimeZone[time_zone]
  end
end
