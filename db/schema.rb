# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_11_14_100000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "vector"

  create_table "accounts", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "custom_instructions"
    t.jsonb "ai_settings", default: {}, null: false
    t.string "time_zone", default: "UTC", null: false
  end

  create_table "chat_messages", force: :cascade do |t|
    t.bigint "integration_id", null: false
    t.string "direction", null: false
    t.string "channel_id", null: false
    t.string "message_id", null: false
    t.string "thread_id"
    t.string "external_user_id"
    t.string "channel_type"
    t.boolean "mentions_app", default: false, null: false
    t.text "text", null: false
    t.datetime "processed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "response_url"
    t.index ["integration_id", "channel_id", "message_id"], name: "idx_on_integration_id_channel_id_message_id_fbb491aab7", unique: true
    t.index ["integration_id"], name: "index_chat_messages_on_integration_id"
  end

  create_table "contacts", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "customer_id"
    t.string "email", null: false
    t.string "name"
    t.string "hubspot_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "email"], name: "index_contacts_on_account_id_and_email", unique: true
    t.index ["account_id"], name: "index_contacts_on_account_id"
    t.index ["customer_id"], name: "index_contacts_on_customer_id"
  end

  create_table "conversations", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "user_id", null: false
    t.string "channel", default: "web", null: false
    t.string "title"
    t.string "chat_channel_id"
    t.string "chat_thread_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "integration_id"
    t.boolean "private_chat", default: false, null: false
    t.text "reply_url"
    t.index ["account_id", "chat_channel_id", "chat_thread_id"], name: "index_conversations_on_slack_thread", unique: true, where: "(chat_thread_id IS NOT NULL)"
    t.index ["account_id"], name: "index_conversations_on_account_id"
    t.index ["integration_id"], name: "index_conversations_on_integration_id"
    t.index ["user_id"], name: "index_conversations_on_user_id"
  end

  create_table "customers", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.string "name", null: false
    t.string "domain"
    t.string "hubspot_id"
    t.bigint "arr_cents", default: 0, null: false
    t.string "plan"
    t.datetime "synced_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "domain"], name: "index_customers_on_account_id_and_domain", unique: true, where: "(domain IS NOT NULL)"
    t.index ["account_id", "hubspot_id"], name: "index_customers_on_account_id_and_hubspot_id", unique: true, where: "(hubspot_id IS NOT NULL)"
    t.index ["account_id"], name: "index_customers_on_account_id"
  end

  create_table "document_suggestions", force: :cascade do |t|
    t.bigint "document_id", null: false
    t.bigint "user_id"
    t.bigint "base_version_id"
    t.text "instruction", null: false
    t.text "body"
    t.text "rationale"
    t.string "status", default: "thinking", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["base_version_id"], name: "index_document_suggestions_on_base_version_id"
    t.index ["document_id"], name: "index_document_suggestions_on_document_id"
    t.index ["user_id"], name: "index_document_suggestions_on_user_id"
  end

  create_table "document_templates", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.string "kind", null: false
    t.string "name", null: false
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "kind"], name: "index_document_templates_on_account_id_and_kind"
    t.index ["account_id"], name: "index_document_templates_on_account_id"
  end

  create_table "document_versions", force: :cascade do |t|
    t.bigint "document_id", null: false
    t.bigint "user_id"
    t.text "body", null: false
    t.string "summary"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["document_id"], name: "index_document_versions_on_document_id"
    t.index ["user_id"], name: "index_document_versions_on_user_id"
  end

  create_table "documents", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "feature_id"
    t.bigint "creator_id"
    t.bigint "document_template_id"
    t.string "kind", null: false
    t.string "title", null: false
    t.text "body", default: "", null: false
    t.string "status", default: "drafting", null: false
    t.boolean "auto_accept", default: false, null: false
    t.bigint "cited_insight_ids", default: [], null: false, array: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "kind"], name: "index_documents_on_account_id_and_kind"
    t.index ["account_id"], name: "index_documents_on_account_id"
    t.index ["creator_id"], name: "index_documents_on_creator_id"
    t.index ["document_template_id"], name: "index_documents_on_document_template_id"
    t.index ["feature_id"], name: "index_documents_on_feature_id"
  end

  create_table "embedding_spaces", force: :cascade do |t|
    t.string "model_alias", null: false
    t.string "upstream_model"
    t.vector "probe", limit: 768, null: false
    t.datetime "activated_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "features", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "product_id", null: false
    t.string "title", null: false
    t.text "description", default: "", null: false
    t.string "status", default: "idea", null: false
    t.virtual "search_vector", type: :tsvector, as: "to_tsvector('simple'::regconfig, (((COALESCE(title, ''::character varying))::text || ' '::text) || COALESCE(description, ''::text)))", stored: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "released_at"
    t.string "linear_issue_id"
    t.string "linear_identifier"
    t.string "linear_url"
    t.string "linear_state"
    t.vector "embedding", limit: 768
    t.bigint "embedding_space_id"
    t.index ["account_id", "linear_issue_id"], name: "index_features_on_account_id_and_linear_issue_id", unique: true, where: "(linear_issue_id IS NOT NULL)"
    t.index ["account_id"], name: "index_features_on_account_id"
    t.index ["embedding"], name: "index_features_on_embedding", opclass: :vector_cosine_ops, using: :hnsw
    t.index ["embedding_space_id"], name: "index_features_on_embedding_space_id"
    t.index ["product_id"], name: "index_features_on_product_id"
    t.index ["search_vector"], name: "index_features_on_search_vector", using: :gin
  end

  create_table "feedback_notes", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "customer_id"
    t.string "source", null: false
    t.string "external_id"
    t.string "author"
    t.string "author_email"
    t.text "body", null: false
    t.datetime "processed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "created_at", "id"], name: "index_feedback_notes_for_list", order: { created_at: :desc, id: :desc }
    t.index ["account_id", "source", "external_id"], name: "index_feedback_notes_on_account_id_and_source_and_external_id", unique: true, where: "(external_id IS NOT NULL)"
    t.index ["account_id"], name: "index_feedback_notes_on_account_id"
    t.index ["customer_id"], name: "index_feedback_notes_on_customer_id"
  end

  create_table "insights", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "feedback_note_id", null: false
    t.bigint "product_id", null: false
    t.bigint "customer_id"
    t.bigint "suggested_feature_id"
    t.bigint "feature_id"
    t.text "quote", null: false
    t.string "summary", null: false
    t.string "urgency", default: "medium", null: false
    t.string "triage_state", default: "pending", null: false
    t.float "match_confidence"
    t.string "match_reason"
    t.virtual "search_vector", type: :tsvector, as: "to_tsvector('simple'::regconfig, (((COALESCE(summary, ''::character varying))::text || ' '::text) || COALESCE(quote, ''::text)))", stored: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.vector "embedding", limit: 768
    t.bigint "embedding_space_id"
    t.index ["account_id", "triage_state", "created_at", "id"], name: "index_insights_for_inbox", order: { created_at: :desc, id: :desc }
    t.index ["account_id", "triage_state"], name: "index_insights_on_account_id_and_triage_state"
    t.index ["account_id"], name: "index_insights_on_account_id"
    t.index ["customer_id"], name: "index_insights_on_customer_id"
    t.index ["embedding"], name: "index_insights_on_embedding", opclass: :vector_cosine_ops, using: :hnsw
    t.index ["embedding_space_id"], name: "index_insights_on_embedding_space_id"
    t.index ["feature_id"], name: "index_insights_on_feature_id"
    t.index ["feedback_note_id"], name: "index_insights_on_feedback_note_id"
    t.index ["product_id"], name: "index_insights_on_product_id"
    t.index ["search_vector"], name: "index_insights_on_search_vector", using: :gin
    t.index ["suggested_feature_id"], name: "index_insights_on_suggested_feature_id"
  end

  create_table "integrations", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.string "type", null: false
    t.string "external_id", null: false
    t.text "access_token"
    t.jsonb "settings", default: {}, null: false
    t.datetime "synced_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "webhook_secret"
    t.text "command_token"
    t.index ["account_id", "type"], name: "index_integrations_on_account_id_and_type", unique: true
    t.index ["account_id"], name: "index_integrations_on_account_id"
    t.index ["type", "external_id"], name: "index_integrations_on_type_and_external_id", unique: true
  end

  create_table "invitations", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "invited_by_id", null: false
    t.string "email", null: false
    t.string "role", default: "member", null: false
    t.string "token_digest", null: false
    t.datetime "accepted_at"
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "email"], name: "index_invitations_on_account_id_and_email"
    t.index ["account_id"], name: "index_invitations_on_account_id"
    t.index ["invited_by_id"], name: "index_invitations_on_invited_by_id"
    t.index ["token_digest"], name: "index_invitations_on_token_digest", unique: true
  end

  create_table "knowledge_documents", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.string "title", null: false
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_knowledge_documents_on_account_id"
  end

  create_table "messages", force: :cascade do |t|
    t.bigint "conversation_id", null: false
    t.string "role", null: false
    t.text "content"
    t.string "status", default: "done", null: false
    t.jsonb "tool_calls", default: [], null: false
    t.bigint "cited_insight_ids", default: [], null: false, array: true
    t.integer "input_tokens"
    t.integer "output_tokens"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["conversation_id"], name: "index_messages_on_conversation_id"
  end

  create_table "products", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.string "name", null: false
    t.string "slug", null: false
    t.text "description", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "slug"], name: "index_products_on_account_id_and_slug", unique: true
    t.index ["account_id"], name: "index_products_on_account_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "skills", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "user_id"
    t.string "name", null: false
    t.string "description", null: false
    t.text "instructions", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "user_id", "name"], name: "index_skills_on_account_id_and_user_id_and_name", unique: true, nulls_not_distinct: true
    t.index ["account_id"], name: "index_skills_on_account_id"
    t.index ["user_id"], name: "index_skills_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.string "name", null: false
    t.string "email_address", null: false
    t.string "slack_user_id"
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "custom_instructions"
    t.string "mcp_token_digest"
    t.string "role", default: "member", null: false
    t.string "mattermost_user_id"
    t.index ["account_id", "mattermost_user_id"], name: "index_users_on_account_id_and_mattermost_user_id", unique: true, where: "(mattermost_user_id IS NOT NULL)"
    t.index ["account_id", "slack_user_id"], name: "index_users_on_account_id_and_slack_user_id", unique: true, where: "(slack_user_id IS NOT NULL)"
    t.index ["account_id"], name: "index_users_on_account_id"
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["mcp_token_digest"], name: "index_users_on_mcp_token_digest", unique: true
    t.check_constraint "email_address::text = lower(email_address::text)", name: "users_email_address_lowercase"
  end

  add_foreign_key "chat_messages", "integrations"
  add_foreign_key "contacts", "accounts"
  add_foreign_key "contacts", "customers"
  add_foreign_key "conversations", "accounts"
  add_foreign_key "conversations", "integrations"
  add_foreign_key "conversations", "users"
  add_foreign_key "customers", "accounts"
  add_foreign_key "document_suggestions", "document_versions", column: "base_version_id"
  add_foreign_key "document_suggestions", "documents"
  add_foreign_key "document_suggestions", "users"
  add_foreign_key "document_templates", "accounts"
  add_foreign_key "document_versions", "documents"
  add_foreign_key "document_versions", "users"
  add_foreign_key "documents", "accounts"
  add_foreign_key "documents", "document_templates"
  add_foreign_key "documents", "features"
  add_foreign_key "documents", "users", column: "creator_id"
  add_foreign_key "features", "accounts"
  add_foreign_key "features", "embedding_spaces"
  add_foreign_key "features", "products"
  add_foreign_key "feedback_notes", "accounts"
  add_foreign_key "feedback_notes", "customers"
  add_foreign_key "insights", "accounts"
  add_foreign_key "insights", "customers"
  add_foreign_key "insights", "embedding_spaces"
  add_foreign_key "insights", "features"
  add_foreign_key "insights", "features", column: "suggested_feature_id"
  add_foreign_key "insights", "feedback_notes"
  add_foreign_key "insights", "products"
  add_foreign_key "integrations", "accounts"
  add_foreign_key "invitations", "accounts"
  add_foreign_key "invitations", "users", column: "invited_by_id"
  add_foreign_key "knowledge_documents", "accounts"
  add_foreign_key "messages", "conversations"
  add_foreign_key "products", "accounts"
  add_foreign_key "sessions", "users"
  add_foreign_key "skills", "accounts"
  add_foreign_key "skills", "users"
  add_foreign_key "users", "accounts"
end
