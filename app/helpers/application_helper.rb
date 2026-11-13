module ApplicationHelper
  MARKDOWN = Redcarpet::Markdown.new(
    Redcarpet::Render::HTML.new(filter_html: true, no_images: true, safe_links_only: true, hard_wrap: true),
    autolink: true, tables: true, strikethrough: true, no_intra_emphasis: true
  )

  def nav_link(label, path, active: false, count: nil)
    link_to path, class: [ "nav-link", ("nav-link--active" if active) ], aria: { current: ("page" if active) } do
      safe_join([ label, (tag.span(count, class: "badge", aria: { label: "#{count} to triage" }) if count&.positive?) ].compact, " ")
    end
  end

  def tab_link(label, path, active)
    link_to label, path, class: [ "tab", ("tab--active" if active) ], aria: { current: ("page" if active) }
  end

  def urgency_pill(urgency)
    tag.span("#{urgency.to_s.humanize} urgency", class: "pill pill--#{urgency}")
  end

  # Markdown from the model is untrusted: raw HTML is filtered out before it renders,
  # then [insight:123] citations become links to the insight.
  # heading_offset demotes headings, so a document's own "# Title" does not compete with the page h1.
  def markdown(text, heading_offset: 0)
    html = MARKDOWN.render(loosen_lists(text.to_s))
    html = html.gsub(%r{<(/?)h([1-6])>}) { "<#{$1}h#{[ $2.to_i + heading_offset, 6 ].min}>" } if heading_offset.positive?
    preload_citations(text.to_s.scan(Message::CITATION).flatten.map(&:to_i))
    html.gsub(Message::CITATION) { citation_link($1.to_i) }.html_safe
  end

  LIST_ITEM = /\A\s*(?:[-*+]|\d+\.)\s+/

  # Models often start a list on the line right after a sentence; Markdown needs a blank line there,
  # otherwise the items render as literal "- " text
  def loosen_lists(text)
    fenced = false
    previous = nil
    text.lines.map do |line|
      fenced = !fenced if line.start_with?("```")
      loose = !fenced && line.match?(LIST_ITEM) && previous.present? && previous.strip.present? && !previous.match?(LIST_ITEM)
      previous = line
      loose ? "\n#{line}" : line
    end.join
  end

  # A citation is a numbered footnote: tapping it shows the quote, the customer and their ARR without leaving the page
  def citation_link(id)
    insight = cited_insights[id]
    return link_to("##{id}", insight_path(id), class: "citation", data: { turbo_frame: "_top" }) unless insight

    popover_id = "citation-#{id}-#{SecureRandom.hex(3)}"
    safe_join([
      tag.button("##{id}", type: "button", class: "citation", popovertarget: popover_id, aria: { label: "Source #{id}: #{insight.summary.truncate(80)}" }),
      tag.span(id: popover_id, popover: "auto", class: "citation-card") do
        safe_join([
          tag.span("“#{insight.quote.truncate(280)}”", class: "citation-card__quote"),
          tag.span(safe_join([ insight.customer&.name || "Unknown customer",
                               (tag.span("#{money(insight.customer.arr_cents)} ARR", class: "arr") if insight.customer) ].compact, " · "), class: "citation-card__who"),
          link_to("Open insight ##{id}", insight_path(id), class: "citation-card__link", data: { turbo_frame: "_top" })
        ])
      end
    ])
  end

  def cited_insights
    @cited_insights ||= {}
  end

  # One query for all citations on the page; insights of other workspaces are never loaded
  def preload_citations(ids)
    missing = ids.uniq - cited_insights.keys
    return if missing.empty? || Current.account.nil?

    found = Current.account.insights.includes(:customer).where(id: missing).index_by(&:id)
    missing.each { |id| cited_insights[id] = found[id] }
  end

  # Shows a Slack message as Slack would: escaped text, <url|label> links clickable, *bold* bold
  def slack_text(text)
    html = ERB::Util.html_escape(text.to_s)
    html = html.gsub(/&lt;(https?:\/\/[^|&]+)\|([^&]+)&gt;/) { link_to($2.html_safe, $1, class: "citation") } # $2 is already escaped
    html = html.gsub(/\*([^*\n]+)\*/, '<strong>\1</strong>')
    simple_format(html, {}, sanitize: false)
  end

  # Links to URLs that came from another system (Linear) only when they are plain https, never javascript: or data:
  def external_link(text, url)
    uri = URI.parse(url.to_s)
    uri.is_a?(URI::HTTPS) ? link_to(text, uri.to_s, target: "_blank", rel: "noopener noreferrer") : text
  rescue URI::InvalidURIError
    text
  end

  TOOL_LABELS = { "search_feedback" => "a feedback search", "feature_demand" => "feature demand", "list_features" => "the backlog",
                   "search_code" => "a code search", "read_file" => "the code" }.freeze

  def tool_label(name) = TOOL_LABELS.fetch(name, name.to_s.humanize.downcase)

  def money(cents)
    number_to_currency(cents.to_i / 100, precision: 0)
  end

  def status_pill(text)
    tag.span(text.to_s.humanize, class: "pill pill--#{text.to_s.dasherize}")
  end
end
