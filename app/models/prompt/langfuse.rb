# Langfuse's prompt API: OxyBot reads text prompts by label or version and uploads new versions.
module Prompt::Langfuse
  Error = ::Langfuse::Error

  module_function

  def configured? = ::Langfuse.configured?

  # choice: a label ("production", "candidate") or a version number
  def fetch(name, choice)
    query = choice.is_a?(Integer) ? "version=#{choice}" : "label=#{ERB::Util.url_encode(choice)}"
    body = ::Langfuse.get("/api/public/v2/prompts/#{ERB::Util.url_encode(name)}?#{query}")
    raise Error, "#{name} is a #{body["type"]} prompt; OxyBot needs a text prompt" unless body["type"] == "text"

    Prompt::Template.new(name: name, text: body.fetch("prompt"), source: "langfuse", version: body["version"],
                         config: body["config"].is_a?(Hash) ? body["config"] : {})
  end

  # Creates a new version; with the label it becomes the one OxyBot uses
  def create(name, text, config:, labels:)
    ::Langfuse.post("/api/public/v2/prompts", { name: name, type: "text", prompt: text, config: config, labels: labels })
  end
end
