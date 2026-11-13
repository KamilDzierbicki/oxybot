class SearchCodeTool < ApplicationTool
  description "Searches the product's code repository and returns matching file paths with a snippet."
  parameter :query, description: "Words to look for, like a class, table or feature name"

  def execute(query:)
    github = account.github_integration
    return { error: "No code repository is connected." } unless github

    { results: github.search_code(query).first(8) }
  end
end
