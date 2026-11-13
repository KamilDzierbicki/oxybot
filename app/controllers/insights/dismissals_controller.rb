class Insights::DismissalsController < ApplicationController
  include InsightScoped

  def create
    @insight.dismiss
    respond_with_triaged "Insight dismissed."
  end
end
