class SkillsController < ApplicationController
  before_action :set_skill, only: %i[edit update destroy]

  def index
    @skills = Skill.available_to(Current.user).includes(:user).alphabetically
  end

  def new
    @skill = Current.account.skills.new
  end

  def create
    @skill = Current.account.skills.new(skill_params)
    if @skill.save
      redirect_to skills_path, notice: "Skill /#{@skill.name} saved. Type it at the start of a question."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @skill.update(skill_params)
      redirect_to skills_path, notice: "Skill saved."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @skill.destroy!
    redirect_to skills_path, notice: "Skill deleted."
  end

  private

  # Team skills are editable by the team; personal ones only by their owner
  def set_skill
    @skill = Skill.available_to(Current.user).find(params[:id])
  end

  def skill_params
    attributes = params.expect(skill: %i[name description instructions personal])
    attributes[:user] = attributes.delete(:personal) == "1" ? Current.user : nil
    attributes
  end
end
