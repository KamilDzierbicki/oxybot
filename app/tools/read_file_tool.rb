class ReadFileTool < ApplicationTool
  MAX_CHARS = 8_000

  description "Reads one file from the product's code repository (a path returned by search_code)."
  parameter :path, description: "File path inside the repository"

  rescue_from ArgumentError, Integration::Github::Client::Error do |error|
    { error: "Could not read that file: #{error.message}" }
  end

  def execute(path:)
    github = account.github_integration
    return { error: "No code repository is connected." } unless github

    { path: path, content: github.read_file(path).truncate(MAX_CHARS) }
  end
end
