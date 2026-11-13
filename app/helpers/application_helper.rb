module ApplicationHelper
  MARKDOWN = Redcarpet::Markdown.new(
    Redcarpet::Render::HTML.new(filter_html: true, no_images: true, safe_links_only: true, hard_wrap: true),
    autolink: true, tables: true, strikethrough: true, no_intra_emphasis: true
  )

  def nav_link(label, path, active: false, count: nil)
    link_to path, class: ["nav-link", ("nav-link--active" if active)] do
      safe_join([label, (tag.span(count, class: "badge") if count&.positive?)].compact, " ")
    end
  end

  # Markdown from the model is untrusted: raw HTML is filtered out before it renders,
  # then [insight:123] citations become links to the insight.
  def markdown(text)
    html = MARKDOWN.render(text.to_s)
    html.gsub(Message::CITATION) { link_to("##{$1}", insight_path($1), class: "citation", data: { turbo_frame: "_top" }) }.html_safe
  end

  def money(cents)
    number_to_currency(cents.to_i / 100, precision: 0)
  end

  def status_pill(text)
    tag.span(text.to_s.humanize, class: "pill pill--#{text.to_s.dasherize}")
  end
end
