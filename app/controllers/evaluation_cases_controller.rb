# Review of evaluation cases learned from corrections: approve one to use it in experiments, or reject it
class EvaluationCasesController < ApplicationController
  admin_only

  def index
    @status = EvaluationCase::STATUSES.include?(params[:status]) ? params[:status] : "pending"
    @cases = Current.account.evaluation_cases.where(status: @status).includes(:insight, :reviewed_by).order(created_at: :desc).limit(100)
  end

  def update
    evaluation_case = Current.account.evaluation_cases.find(params[:id])
    status = params.expect(:status)
    return head :unprocessable_entity unless %w[approved rejected].include?(status)

    evaluation_case.review(status, by: Current.user)
    redirect_to evaluation_cases_path
  end
end
