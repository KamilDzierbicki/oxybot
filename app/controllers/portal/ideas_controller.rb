# An idea from a customer becomes feedback like any other: the extractor splits it into insights for triage
class Portal::IdeasController < Portal::BaseController
  rate_limit to: 5, within: 1.hour, only: :create, by: -> { "#{portal.id}:#{current_visitor&.id || request.remote_ip}" },
             with: -> { redirect_to portal_root_path(portal_slug: params[:portal_slug]), alert: "Thanks! That is enough ideas for one hour." }
  before_action :require_visitor

  def new
    @note = portal.feedback_notes.new
  end

  def create
    @note = portal.feedback_notes.new(source: "portal", author_email: current_visitor.email, customer: current_visitor.customer,
                                      body: params.expect(feedback_note: [ :body ])[:body].to_s.strip.first(5_000))
    if @note.save
      redirect_to portal_root, notice: "Thank you. The product team reads every idea."
    else
      render :new, status: :unprocessable_entity
    end
  end
end
