# The version of the skill registered in Langfuse, so traces can link usage to it
class AddLangfuseVersionToSkills < ActiveRecord::Migration[8.1]
  def change
    add_column :skills, :langfuse_version, :integer
  end
end
