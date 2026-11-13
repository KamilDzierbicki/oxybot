# Hands a feature to engineering in Linear and keeps its status in step with the issue, both ways.
module Feature::Deliverable
  extend ActiveSupport::Concern

  included do
    attr_accessor :syncing_from_linear
    after_update_commit :move_linear_issue_later, if: -> { saved_change_to_status? && linear_issue_id.present? && !syncing_from_linear }
    before_save :stamp_release, if: -> { will_save_change_to_status? && status == "released" }
  end

  def in_linear? = linear_issue_id.present? && !linear_issue_id.start_with?("pending-")

  # The row is claimed before calling Linear, so two quick clicks cannot create two issues
  def send_to_linear
    claimed = self.class.where(id: id, linear_issue_id: nil).update_all(linear_issue_id: "pending-#{SecureRandom.hex(4)}", updated_at: Time.current)
    raise ArgumentError, "Already in Linear as #{reload.linear_identifier || "an issue being created"}" if claimed.zero?

    spec = account.documents.specs.ready.where(feature: self).order(:id).last
    issue = account.linear_integration.create_issue(title: title, description: linear_description(spec))
    update!(linear_issue_id: issue[:id], linear_identifier: issue[:identifier], linear_url: issue[:url], linear_state: issue[:state])
  rescue StandardError => e
    self.class.where(id: id).where("linear_issue_id LIKE 'pending-%'").update_all(linear_issue_id: nil) unless e.is_a?(ArgumentError)
    raise
  end

  def move_linear_issue_later
    MoveLinearIssueJob.perform_later(self)
  end

  def move_linear_issue
    return unless in_linear? && account.linear_integration

    update_column(:linear_state, account.linear_integration.move_issue(linear_issue_id, status))
  end

  # Called by the Linear webhook. It does not echo the change back to Linear.
  def apply_linear_state(type:, name:)
    self.syncing_from_linear = true
    update!(status: Integration::Linear::STATUS_BY_STATE_TYPE.fetch(type, status), linear_state: name)
  ensure
    self.syncing_from_linear = false
  end

  private

  def stamp_release
    self.released_at ||= Time.current
  end

  def linear_description(spec)
    link = Rails.application.routes.url_helpers.feature_url(self, **Rails.application.config.x.url_options)
    [ spec&.body.presence || description, "---", "Customer evidence and the latest spec: #{link}" ].join("\n\n")
  end
end
