class DocumentVersion < ApplicationRecord
  belongs_to :document, touch: true
  belongs_to :user, optional: true

  def author_name = user&.name || "OxyBot agent"

  def previous
    document.versions.where(id: ...id).last
  end
end
