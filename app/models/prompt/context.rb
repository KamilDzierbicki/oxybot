# The variables shared by OxyBot's prompts: who is asking, the products, company knowledge and instructions.
class Prompt::Context
  def initialize(account, user = nil)
    @account = account
    @user = user
  end

  def to_h
    {
      account_name: @account.name,
      user_name: @user&.name || "the product team",
      products: products,
      company_context: company_context,
      team_instructions: section("Team instructions", @account.custom_instructions),
      personal_instructions: section("Personal instructions of #{@user&.name}", @user&.custom_instructions)
    }
  end

  def products
    @account.products.alphabetically.map { |product| "- #{product.slug}: #{product.name}. #{product.description.squish}" }.join("\n")
  end

  private

  # Short documents in full; long ones only by title, since the agent searches their sections with search_knowledge
  def company_context
    long, short = @account.knowledge_documents.alphabetically.partition(&:long?)
    parts = short.map { |document| "## #{document.title}\n#{document.body.strip}" }
    if long.any?
      parts << "Longer company documents, not included here; search them with the search_knowledge tool when a question needs them:\n" +
               long.map { |document| "- #{document.title}" }.join("\n")
    end
    parts.any? ? "Company context:\n\n#{parts.join("\n\n")}" : ""
  end

  def section(title, text)
    text.present? ? "#{title}:\n#{text.strip}" : ""
  end
end
