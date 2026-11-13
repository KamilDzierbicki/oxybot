# Puts a linked or dismissed insight back into triage: the undo for Link and Dismiss.
class Insights::RestorationsController < ApplicationController
  include InsightScoped

  def create
    @insight.restore
    redirect_back_or_to insights_path, notice: "Moved back to triage."
  end
end
