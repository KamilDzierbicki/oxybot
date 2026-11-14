# RICE prioritization: reach is counted from the customers asking; impact, confidence and effort are set by people
class AddRiceToFeatures < ActiveRecord::Migration[8.1]
  def change
    add_column :features, :impact, :decimal, precision: 4, scale: 2
    add_column :features, :confidence, :integer
    add_column :features, :effort, :decimal, precision: 6, scale: 1
    add_check_constraint :features, "impact IS NULL OR impact IN (0.25, 0.5, 1, 2, 3)", name: "features_impact_scale"
    add_check_constraint :features, "confidence IS NULL OR confidence IN (50, 80, 100)", name: "features_confidence_scale"
    add_check_constraint :features, "effort IS NULL OR effort > 0", name: "features_effort_positive"
  end
end
