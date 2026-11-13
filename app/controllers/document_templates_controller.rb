class DocumentTemplatesController < ApplicationController
  admin_only except: :index
  before_action :set_template, only: %i[edit update]

  def index
    @templates = Current.account.document_templates.ordered
  end

  def new
    @template = Current.account.document_templates.new(kind: params[:kind])
  end

  def create
    @template = Current.account.document_templates.new(template_params)
    if @template.save
      redirect_to document_templates_path, notice: "Template added."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @template.update(template_params)
      redirect_to document_templates_path, notice: "Template saved."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_template
    @template = Current.account.document_templates.find(params[:id])
  end

  def template_params
    params.expect(document_template: %i[kind name body])
  end
end
