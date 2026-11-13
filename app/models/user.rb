class User < ApplicationRecord
  has_secure_password
  belongs_to :account
  has_many :sessions, dependent: :destroy
  has_many :conversations, dependent: :destroy
  has_many :skills, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }
  normalizes :slack_user_id, with: ->(id) { id.strip.presence }

  validates :name, presence: true

  # A personal token for coding agents (MCP). Only its digest is stored; the token is shown once.
  def generate_mcp_token
    token = "oxy_#{SecureRandom.base58(32)}"
    update!(mcp_token_digest: self.class.digest_mcp_token(token))
    token
  end

  def self.digest_mcp_token(token) = Digest::SHA256.hexdigest(token.to_s)

  def self.find_by_mcp_token(token)
    find_by(mcp_token_digest: digest_mcp_token(token)) if token.present?
  end
end
