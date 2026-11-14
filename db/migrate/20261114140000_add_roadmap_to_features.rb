# Roadmap lane (now, next, later; null = not on the roadmap) and whether customers see the feature on the portal
class AddRoadmapToFeatures < ActiveRecord::Migration[8.1]
  def change
    add_column :features, :roadmap_lane, :string
    add_column :features, :on_portal, :boolean, default: false, null: false
    add_check_constraint :features, "roadmap_lane IS NULL OR roadmap_lane IN ('now', 'next', 'later')", name: "features_roadmap_lane"
    add_index :features, [ :account_id, :roadmap_lane ]
  end
end
