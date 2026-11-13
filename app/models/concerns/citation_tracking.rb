# For anything that lets a model write text with [insight:123] citations: tools report the insights they
# returned, and a citation of an insight no tool or brief provided is invented (or from another tenant).
module CitationTracking
  def seen_insight_ids
    @seen_insight_ids ||= Set.new
  end

  def remember_insights(ids)
    seen_insight_ids.merge(ids)
  end

  # Returns the text without unknown citations, and the ids it still cites
  def checked_citations(content)
    cited = []
    checked = content.to_s.gsub(Message::CITATION) do
      id = $1.to_i
      next "" unless seen_insight_ids.include?(id)

      cited << id
      "[insight:#{id}]"
    end
    [ checked.gsub(/ +\n/, "\n").strip, cited.uniq ]
  end
end
