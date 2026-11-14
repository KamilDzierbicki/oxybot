# Langfuse's prompt API: OxyBot reads text prompts by label and uploads new versions.
module Prompt::Langfuse
  Error = ::Langfuse::Error

  module_function

  def configured? = ::Langfuse.configured?

  def fetch(name, label:)
    body = ::Langfuse.get("/api/public/v2/prompts/#{ERB::Util.url_encode(name)}?label=#{ERB::Util.url_encode(label)}")
    raise Error, "#{name} is a #{body["type"]} prompt; OxyBot needs a text prompt" unless body["type"] == "text"

    Prompt::Template.new(name: name, text: body.fetch("prompt"), source: "langfuse", version: body["version"])
  end

  # Creates a new version; with the label it becomes the one OxyBot uses
  def create(name, text, labels:)
    ::Langfuse.post("/api/public/v2/prompts", { name: name, type: "text", prompt: text, labels: labels })
  end
end
