class TeamInstructionsController < ApplicationController
  def update
    Current.account.update!(custom_instructions: params.expect(account: [ :custom_instructions ])[:custom_instructions])
    redirect_to knowledge_documents_path, notice: "Team instructions saved."
  end
end
