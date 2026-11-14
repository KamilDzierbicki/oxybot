# Groundwork for Intercom, Zendesk, Gong, Salesforce, Amplitude, Pendo and Hex
class PrepareMoreIntegrations < ActiveRecord::Migration[8.1]
  def change
    # A second credential (key secret, client secret), encrypted like the access token
    add_column :integrations, :secret, :text

    add_column :customers, :salesforce_id, :string
    add_index :customers, [ :account_id, :salesforce_id ], unique: true, where: "salesforce_id IS NOT NULL"
    add_column :contacts, :salesforce_id, :string

    # The analytics event (Amplitude), feature id (Pendo) or metric name (Hex) that marks use of the feature
    add_column :features, :analytics_key, :string
  end
end
