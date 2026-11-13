class KnowledgeDocumentsController < ApplicationController
  before_action :set_document, only: %i[edit update destroy]

  def index
    @documents = Current.account.knowledge_documents.alphabetically
  end

  def new
    @document = Current.account.knowledge_documents.new
  end

  def create
    @document = Current.account.knowledge_documents.new(document_params)
    if @document.save
      redirect_to knowledge_documents_path, notice: "Document added. The assistant uses it from the next question."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @document.update(document_params)
      redirect_to knowledge_documents_path
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @document.destroy!
    redirect_to knowledge_documents_path
  end

  private

  def set_document
    @document = Current.account.knowledge_documents.find(params[:id])
  end

  def document_params
    params.expect(knowledge_document: %i[title body])
  end
end
