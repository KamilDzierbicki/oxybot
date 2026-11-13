class TeamInstructionsController < ApplicationController
  admin_only

  def update
    Current.account.update!(custom_instructions: params.expect(account: [ :custom_instructions ])[:custom_instructions])
    redirect_to knowledge_documents_path, notice: "Team instructions saved."
  end
end
