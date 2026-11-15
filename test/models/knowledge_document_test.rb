require "test_helper"

# Long company documents must not crowd every prompt, yet the agent must still be able to find any part of them.
class KnowledgeDocumentTest < ActiveSupport::TestCase
  setup { @account = accounts(:acme) }

  test "a short document goes into the agent's context in full and is not split" do
    document = @account.knowledge_documents.create!(title: "Strategy", body: "Win mid-market logistics in 2027.")

    assert_empty document.chunks
    assert_includes Prompt::Context.new(@account).to_h[:company_context], "Win mid-market logistics in 2027."
  end

  test "a long document is split at its headings into sections that keep every word, and the prompt only names it" do
    document = @account.knowledge_documents.create!(title: "Pricing handbook", body: long_body)

    sections = document.chunks.to_a
    assert_operator sections.size, :>, 2
    assert sections.all? { |chunk| chunk.body.length <= KnowledgeDocument::CHUNK_SIZE }, "a section fits one search result"
    assert_equal [ "Plans", "Discounts", "Competitors" ], sections.map(&:heading).uniq.compact
    assert_equal words(long_body.gsub(/^#+ .*$/, "")), words(sections.map(&:body).join(" ")), "splitting drops no text"

    context = Prompt::Context.new(@account).to_h[:company_context]
    assert_includes context, "- Pricing handbook"
    assert_not_includes context, "Nonprofits get 40% off", "the long body stays out of every prompt"
  end

  test "a paragraph longer than a section is split at sentence ends without losing text" do
    paragraph = ([ "Enterprise contracts renew every January with a written notice." ] * 90).join(" ")
    document = @account.knowledge_documents.create!(title: "Contracts", body: paragraph)
    assert document.long?, "the example must be over the prompt limit, or the test proves nothing"

    assert document.chunks.all? { |chunk| chunk.body.length <= KnowledgeDocument::CHUNK_SIZE }
    assert_equal words(paragraph), words(document.chunks.map(&:body).join(" "))
  end

  test "shortening a document puts it back in the prompt and removes its sections" do
    document = @account.knowledge_documents.create!(title: "Pricing handbook", body: long_body)
    assert_not_empty document.chunks

    document.update!(body: "Three plans: Starter, Growth, Enterprise.")

    assert_empty KnowledgeChunk.where(knowledge_document: document)
    assert_includes Prompt::Context.new(@account).to_h[:company_context], "Three plans"
  end

  test "a long document saved before sections existed gets them once, and short ones stay whole" do
    long = @account.knowledge_documents.create!(title: "Pricing handbook", body: long_body)
    short = @account.knowledge_documents.create!(title: "Strategy", body: "Win mid-market logistics in 2027.")
    long.chunks.delete_all

    assert_enqueued_with(job: EmbedJob, args: [ long ]) { KnowledgeDocument.build_missing_chunks }
    assert_not_empty long.chunks.reload, "without sections the prompt lists a document nobody can search"
    assert_empty short.chunks
    assert_no_enqueued_jobs(only: EmbedJob) { KnowledgeDocument.build_missing_chunks }
  end

  test "the agent finds a section of a long document, and only in its own workspace" do
    @account.knowledge_documents.create!(title: "Pricing handbook", body: long_body).embed
    accounts(:globex).knowledge_documents.create!(title: "Globex pricing", body: long_body.gsub("Nonprofits", "Universities")).embed

    passages = SearchKnowledgeTool.new(Struct.new(:account).new(@account)).execute(query: "nonprofit discount")[:passages]

    assert_includes passages.first[:text], "Nonprofits get 40% off"
    assert_equal [ "Pricing handbook" ], passages.map { |passage| passage[:document] }.uniq
  end

  test "the assistant searches long documents only when the workspace has one" do
    question = "What is our pricing strategy for nonprofits?"
    assert_equal [ "search_feedback" ], tools_used(question), "no long document: the knowledge tool is not offered"

    @account.knowledge_documents.create!(title: "Pricing handbook", body: long_body).embed

    assert_equal [ "search_knowledge" ], tools_used(question)
  end

  private

  def tools_used(question)
    reply = users(:kamil).conversations.create!(account: @account).ask(question)
    perform_enqueued_jobs(only: GenerateReplyJob)
    reply.reload.tool_calls.map { |call| call["name"] }
  end

  def words(text) = text.split

  def long_body
    plans = (1..20).map { |n| "Plan tier #{n} includes #{n * 5} dashboards, #{n * 2} editors and email support within #{48 / n} hours." }
    discounts = (1..20).map { |n| "Discount rule #{n}: annual prepayment of #{n} years lowers the price by #{n * 3}% for new contracts." }
    <<~MARKDOWN
      Our pricing is per workspace, billed monthly or yearly.

      # Plans
      #{plans.join("\n\n")}

      ## Discounts
      Nonprofits get 40% off every plan after a quick check of their registration.

      #{discounts.join("\n\n")}

      ## Competitors
      #{(1..15).map { |n| "Competitor #{n} charges per seat, which costs larger teams about #{n * 10}% more than our workspace price." }.join("\n\n")}
    MARKDOWN
  end
end
