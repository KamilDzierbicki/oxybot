# One embedding model, recognized by its fingerprint: the vector it gives for a fixed sentence. Every embedding call
# sends that sentence along with the real texts, so the response itself says which model made the vectors, even when
# the oxybot-embed alias was pointed at another model with the same number of dimensions.
class EmbeddingSpace < ApplicationRecord
  PROBE = "search_document: OxyBot embedding fingerprint. This sentence must never change."
  # The same model gives the same probe vector (measured: distance 0.0, also inside a batch); unrelated texts
  # from one model are about 0.5 apart, so anything over this is another model
  SAME_MODEL_DISTANCE = 0.02
  LOCK = 0x0e3b_ed01 # advisory lock key, so two jobs seeing a new model create one space, not two

  has_neighbors :probe
  has_many :features, dependent: :nullify
  has_many :insights, dependent: :nullify

  # The space the alias serves now; vectors from any other space are stale
  def self.active = order(activated_at: :desc, id: :desc).first

  # Embeds texts in one call together with the probe. Returns [space, vectors].
  def self.embed(texts, task: :document)
    inputs = [ PROBE ] + texts.map { |text| Embeddable::PREFIXES.fetch(task) + text.to_s }
    probe, *vectors = RubyLLM.embed(inputs, model: Embeddable::MODEL, provider: :openai, assume_model_exists: true).vectors
    [ identify(probe), vectors ]
  end

  def self.identify(probe)
    unless probe.size == Embeddable::DIMENSIONS
      raise ArgumentError, "#{Embeddable::MODEL} returns #{probe.size} dimensions, the vector columns hold #{Embeddable::DIMENSIONS}"
    end

    space = closest(probe)
    return space if space&.active?

    transaction do
      connection.execute("SELECT pg_advisory_xact_lock(#{LOCK})")
      space = closest(probe)
      if space.nil?
        create!(model_alias: Embeddable::MODEL, upstream_model: upstream_model, probe: probe, activated_at: Time.current)
      else
        # The alias went back to a model used before: its old vectors are valid again, the others are stale
        space.tap { it.update!(activated_at: Time.current) unless it.active? }
      end
    end.tap { |result| result.reembed_everywhere if result.previously_new_record? || result.saved_change_to_activated_at? }
  end

  def self.closest(probe)
    space = nearest_neighbors(:probe, probe, distance: "cosine").first
    space if space && space.neighbor_distance < SAME_MODEL_DISTANCE
  end

  # What LiteLLM serves behind the alias, shown to people; the fingerprint, not this name, decides sameness
  def self.upstream_model
    uri = URI("#{Rails.configuration.x.llm_url}/model/info")
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 2, read_timeout: 3) do |http|
      http.get(uri.request_uri, "Authorization" => "Bearer #{ENV.fetch("LITELLM_API_KEY", "sk-oxybot-local")}")
    end
    JSON.parse(response.body).fetch("data").find { |model| model["model_name"] == Embeddable::MODEL }&.dig("litellm_params", "model")
  rescue StandardError
    nil
  end

  def active? = self == self.class.active

  def name = upstream_model.presence || model_alias

  def reembed_everywhere
    Account.find_each { |account| ReembedJob.perform_later(account) }
  end
end
