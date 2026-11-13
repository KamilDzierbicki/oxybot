class Insights::DismissalsController < ApplicationController
  include InsightScoped

  def create
    @insight.dismiss
    respond_with_triaged "Dismissed “#{@insight.summary.truncate(60)}”"
  end
end
