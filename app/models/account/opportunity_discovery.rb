# The numbers behind the weekly opportunity report, computed in SQL and Ruby, never by the model:
# what grew this week, which needs have no feature yet (emerging themes), which segments ask for what,
# and where demand and the roadmap disagree.
class Account::OpportunityDiscovery
  THEME_DISTANCE = 0.35 # cosine distance under which two unlinked insights count as the same theme
  THEME_WINDOW = 30.days

  def initialize(account, now: Time.current)
    @account = account
    @this_week = (now - 7.days)..now
    @last_week = (now - 14.days)...(now - 7.days)
  end

  def new_insight_counts
    { this_week: @account.insights.where(created_at: @this_week).count, last_week: @account.insights.where(created_at: @last_week).count }
  end

  # Features whose linked insights grew the most this week compared with the week before
  def growing_features(limit: 5)
    this_week = Arel.sql(Insight.sanitize_sql_array([ "COUNT(*) FILTER (WHERE insights.created_at >= ?)", @this_week.begin ]))
    last_week = Arel.sql(Insight.sanitize_sql_array([ "COUNT(*) FILTER (WHERE insights.created_at < ?)", @this_week.begin ]))
    counts = @account.insights.where.not(feature_id: nil).where(created_at: @last_week.begin..@this_week.end)
                     .group(:feature_id).pluck(:feature_id, this_week, last_week)
    features = @account.features.with_demand.where(id: counts.map(&:first)).index_by(&:id)
    counts.map { |id, now_count, before_count| { feature: features[id], this_week: now_count, last_week: before_count, growth: now_count - before_count } }
          .select { |row| row[:this_week].positive? }.sort_by { |row| [ -row[:growth], -row[:this_week] ] }.first(limit)
  end

  # Unlinked needs without a suggested feature, grouped greedily by embedding distance: candidates for new features
  def emerging_themes(min_size: 2)
    insights = @account.insights.pending.where(suggested_feature_id: nil, created_at: THEME_WINDOW.ago..)
                       .where.not(embedding: nil).includes(:customer).order(:id).to_a
    themes = []
    insights.each do |insight|
      theme = themes.find { |members| cosine_distance(members.first.embedding, insight.embedding) < THEME_DISTANCE }
      theme ? theme << insight : themes << [ insight ]
    end
    themes.select { |members| members.size >= min_size }.sort_by { |members| -members.sum { |insight| insight.customer&.arr_cents.to_i } }
  end

  # ARR and customers asking, per plan, for the top features
  def segments(limit: 5)
    top = @account.features.by_demand.limit(limit).to_a
    # One row per feature and customer, so a customer's ARR counts once per feature
    rows = @account.insights.joins(:customer).where(feature_id: top.map(&:id)).distinct
                   .pluck(:feature_id, "customers.id", "customers.plan", "customers.arr_cents")
    top.map do |feature|
      by_plan = rows.select { |row| row.first == feature.id }.group_by { |row| row[2] || "No plan" }
      { feature: feature, plans: by_plan.map { |plan, group| { plan: plan, customers: group.size, arr_cents: group.sum(&:last) } } }
    end
  end

  # High demand still parked as an idea, or work in progress nobody asked for
  def roadmap_gaps
    features = @account.features.by_demand.to_a
    { underserved: features.select { |feature| feature.status == "idea" && feature.insight_count.positive? }.first(3),
      unasked: features.select { |feature| feature.status.in?(%w[planned in_progress]) && feature.insight_count.zero? } }
  end

  def to_brief(generation)
    counts = new_insight_counts
    themes = emerging_themes
    generation.remember_insights(themes.flatten.map(&:id))
    gaps = roadmap_gaps

    growing = list(growing_features) { |row| growing_line(row) }
    emerging = list(themes) { |members| theme_line(members) }
    segment_lines = list(segments) { |row| "- #{row[:feature].title}: " + row[:plans].map { |plan| "#{plan[:plan]} #{plan[:customers]} customers, #{money(plan[:arr_cents])}" }.join("; ") }
    underserved = gaps[:underserved].map { |feature| "#{feature.title} (#{money(feature.demand_arr_cents)})" }.join(", ").presence || "none"

    [
      "New insights: #{counts[:this_week]} this week, #{counts[:last_week]} the week before.",
      "Growing features:\n#{growing}",
      "Emerging themes without a feature (candidates for the backlog):\n#{emerging}",
      "Segments asking for the top features:\n#{segment_lines}",
      "Roadmap check:\n- Demand but still an idea: #{underserved}\n" \
        "- Planned or in progress with no customer evidence: #{gaps[:unasked].map(&:title).join(", ").presence || "none"}"
    ].join("\n\n")
  end

  private

  def list(rows, &block)
    rows.empty? ? "- none" : rows.map(&block).join("\n")
  end

  def growing_line(row)
    feature = row[:feature]
    "- #{feature.title} (#{feature.status}): #{row[:this_week]} this week vs #{row[:last_week]} before; " \
      "total #{feature.insight_count} insights, #{money(feature.demand_arr_cents)} ARR"
  end

  def theme_line(members)
    customers = members.filter_map(&:customer).uniq
    "- #{members.size} insights from #{customers.size} customers (#{money(customers.sum(&:arr_cents))} ARR): " +
      members.first(4).map { |insight| "[insight:#{insight.id}] #{insight.summary}" }.join("; ")
  end

  def money(cents) = ActiveSupport::NumberHelper.number_to_currency(cents.to_i / 100, precision: 0)

  def cosine_distance(a, b)
    a, b = a.to_a, b.to_a
    dot = a.zip(b).sum { |x, y| x * y }
    1 - dot / (Math.sqrt(a.sum { |x| x * x }) * Math.sqrt(b.sum { |y| y * y }))
  end
end
