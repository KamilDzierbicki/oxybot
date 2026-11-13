class DocumentsController < ApplicationController
  # Each call costs model tokens; the limit keeps one user from running up the bill
  rate_limit to: 5, within: 1.minute, only: :create, by: -> { Current.user.id },
             with: -> { redirect_back_or_to root_path, alert: "Slow down a little: too many requests in a minute." }
  before_action :set_document, only: %i[show edit update]

  # Kinds a person starts from this page; specs and launch reviews start from a feature
  STANDALONE_KINDS = %w[voc_report opportunity_report release_notes].freeze

  def index
    @documents = Current.account.documents.includes(:feature, :creator).latest_first
    @documents = @documents.where(kind: params[:kind]) if Document::KINDS.key?(params[:kind])
  end

  def show
    @suggestions = @document.suggestions.includes(:user, :base_version).where(status: %w[thinking pending failed]).order(id: :desc)
  end

  def create
    kind = params.expect(:kind)
    return head :unprocessable_entity unless STANDALONE_KINDS.include?(kind)

    redirect_to Document.draft(account: Current.account, kind: kind, creator: Current.user)
  end

  def edit; end

  def update
    attributes = params.expect(document: %i[title body auto_accept])
    @document.update!(title: attributes[:title]) if attributes[:title].present?
    @document.update!(auto_accept: attributes[:auto_accept] == "1") if attributes.key?(:auto_accept)
    if attributes.key?(:body) && attributes[:body] != @document.body
      return redirect_to(edit_document_path(@document), alert: "The document cannot be empty.") if attributes[:body].blank?

      @document.edit(attributes[:body], user: Current.user, summary: params[:summary].presence || "Edited by #{Current.user.name}")
    end
    redirect_to @document
  end

  private

  def set_document
    @document = Current.account.documents.find(params[:id])
  end
end
