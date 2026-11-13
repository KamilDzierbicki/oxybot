# Feedback and chat text come from outsiders. Zero-width, bidi-override and Unicode tag characters can hide
# instructions from people while models still read them, so they are removed before the text is stored.
module VisibleText
  INVISIBLE = /[\u00AD\u200B-\u200F\u202A-\u202E\u2060-\u2064\u2066-\u2069\uFEFF\u{E0000}-\u{E007F}]/

  def self.clean(text)
    text&.gsub(INVISIBLE, "")
  end
end
