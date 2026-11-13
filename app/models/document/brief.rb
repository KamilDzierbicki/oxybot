# The facts a document is written from, gathered by code (rule: if code can answer, code answers).
# Each evidence line carries its insight id, so the writer can cite it and the citation check accepts it.
class Document::Brief
  RECENT = 30.days

  def initialize(document, generation)
    @document = document
    @generation = generation
    @account = document.account
  end

  def to_s
    [ "Write the #{@document.kind_name.downcase} titled \"#{@document.title}\".", template, *send("#{@document.kind}_sections") ]
      .compact.join("\n\n")
  end

  private

  def template
    body = @document.document_template&.body || DocumentTemplate.default_body(@document.kind)
    "Template (keep its headings, replace the guidance):\n<template>\n#{body.strip}\n</template>"
  end

  def prd_sections
    feature = @document.feature
    [
      "Feature: #{feature.title} (#{feature.product.name}, status #{feature.status})\n#{feature.description}",
      demand_line(feature),
      evidence("Evidence (linked customer insights):", feature.insights.includes(:customer).latest_first.limit(15)),
      code_context(feature)
    ]
  end

  def voc_report_sections
    insights = @account.insights.where(created_at: RECENT.ago..).where.not(triage_state: "dismissed").includes(:customer, :feature, :product)
    by_feature = insights.group_by { |insight| insight.feature&.title || "Not linked to a feature yet" }
    [
      "Period: last 30 days. #{insights.size} insights from #{insights.map(&:customer_id).compact.uniq.size} known customers.",
      *by_feature.sort_by { |_title, group| -group.size }.first(8).map { |title, group| evidence("Theme: #{title} (#{group.size} insights)", group.first(5)) }
    ]
  end

  def opportunity_report_sections
    discovery = Account::OpportunityDiscovery.new(@account)
    [ discovery.to_brief(@generation) ]
  end

  def release_notes_sections
    features = @account.features.where(status: "released", released_at: RECENT.ago..).includes(:product, insights: { customer: :contacts })
    return [ "No features were released in the last 30 days. Say so briefly." ] if features.empty?

    features.map do |feature|
      customers = feature.insights.filter_map(&:customer).uniq
      contacts = customers.flat_map(&:contacts).map { |contact| "#{contact.name || contact.email} <#{contact.email}> (#{contact.customer&.name})" }
      [ "Released: #{feature.title} (#{feature.product.name}) on #{feature.released_at.to_date.to_fs(:long)}\n#{feature.description}",
        evidence("Customers who asked for it:", feature.insights.includes(:customer).limit(8)),
        "Contacts to notify: #{contacts.presence&.join("; ") || "none known"}" ].join("\n")
    end
  end

  def launch_review_sections
    feature = @document.feature
    released_at = feature.released_at || feature.updated_at
    before = feature.insights.where(created_at: ...released_at)
    after = @account.insights.where(product: feature.product, created_at: released_at..).includes(:customer)
    after = after.hybrid_search(feature.title, limit: 10) if after.any?
    spec = @account.documents.specs.where(feature: feature).ready.order(:id).last
    usage = Feature::UsageMetrics.for(feature)

    [
      "Feature: #{feature.title}, released #{released_at.to_date.to_fs(:long)}. #{before.count} insights asked for it before release.",
      "Success metrics from the spec:\n#{spec&.section("Success metrics", "Goals", "Metrics") || "The spec has no success metrics."}",
      "Usage (#{usage ? "from #{usage[:source]}" : "no analytics connected"}):\n#{usage ? usage[:lines].join("\n") : "Not available; say what to measure."}",
      evidence("Feedback about #{feature.product.name} since the release (closest to this feature first):", after)
    ]
  end

  def demand_line(feature)
    demand = @account.features.with_demand.find(feature.id)
    "Demand: #{demand.insight_count} insights from #{demand.customer_count} customers, " \
      "#{ActiveSupport::NumberHelper.number_to_currency(demand.demand_arr_cents / 100, precision: 0)} ARR."
  end

  def evidence(heading, insights)
    insights = insights.to_a
    @generation.remember_insights(insights.map(&:id))
    return "#{heading}\n- none" if insights.empty?

    lines = insights.map do |insight|
      who = insight.customer ? "#{insight.customer.name}, #{ActiveSupport::NumberHelper.number_to_currency(insight.customer.arr, precision: 0)} ARR" : "unknown customer"
      "- [insight:#{insight.id}] #{insight.summary} (#{who}, #{insight.urgency} urgency). Quote: \"#{insight.quote.squish.truncate(200)}\""
    end
    "#{heading}\n#{lines.join("\n")}"
  end

  def code_context(feature)
    github = @account.github_integration
    return "Code: no repository connected." unless github

    hits = github.search_code(feature.title).first(5)
    return "Code: nothing in #{github.repository} matches \"#{feature.title}\". You can search further with search_code." if hits.empty?

    "Code (from #{github.repository}; search further with search_code and read_file):\n" +
      hits.map { |hit| "- #{hit[:path]}: #{hit[:snippet].squish.truncate(240)}" }.join("\n")
  end
end
