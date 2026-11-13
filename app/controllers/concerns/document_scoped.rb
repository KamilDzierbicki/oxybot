module DocumentScoped
  extend ActiveSupport::Concern

  included do
    before_action :set_document
  end

  private

  def set_document
    @document = Current.account.documents.find(params[:document_id])
  end
end
