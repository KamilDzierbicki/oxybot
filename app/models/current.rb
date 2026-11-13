class Current < ActiveSupport::CurrentAttributes
  attribute :session, :account
  delegate :user, to: :session, allow_nil: true

  def session=(value)
    super
    self.account = value&.user&.account
  end
end
