# Slack and Mattermost share one model of chat messages and conversations, so each new chat platform is an
# adapter, not a copy of the routing logic.
class GeneralizeChatIntegrations < ActiveRecord::Migration[8.1]
  def change
    rename_table :slack_messages, :chat_messages
    rename_column :chat_messages, :ts, :message_id
    rename_column :chat_messages, :thread_ts, :thread_id
    rename_column :chat_messages, :slack_user_id, :external_user_id
    add_column :chat_messages, :response_url, :text

    rename_column :conversations, :slack_channel_id, :chat_channel_id
    rename_column :conversations, :slack_thread_ts, :chat_thread_id
    add_reference :conversations, :integration, foreign_key: true
    add_column :conversations, :private_chat, :boolean, null: false, default: false
    # Slash command answers go back through the URL Mattermost sent with the command
    add_column :conversations, :reply_url, :text

    add_column :users, :mattermost_user_id, :string
    add_index :users, [ :account_id, :mattermost_user_id ], unique: true, where: "mattermost_user_id IS NOT NULL"

    add_column :integrations, :command_token, :text

    reversible do |direction|
      direction.up do
        execute <<~SQL
          UPDATE conversations SET integration_id = integrations.id, private_chat = (conversations.chat_channel_id LIKE 'D%')
          FROM integrations WHERE integrations.account_id = conversations.account_id
            AND integrations.type = 'Integration::Slack' AND conversations.channel = 'slack'
        SQL
      end
    end
  end
end
