class User < ApplicationRecord
  has_secure_password
  belongs_to :account
  has_many :sessions, dependent: :destroy
  has_many :conversations, dependent: :destroy
  has_many :skills, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }
  normalizes :slack_user_id, :mattermost_user_id, with: ->(id) { id.strip.presence }

  ROLES = %w[admin member].freeze

  validates :name, presence: true
  validates :role, inclusion: { in: ROLES }
  validate :account_keeps_an_admin, on: :update

  before_destroy :ensure_not_last_admin

  scope :alphabetically, -> { order(:name) }

  def admin? = role == "admin"

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

  private

  def account_keeps_an_admin
    return unless will_save_change_to_role? || role_changed?
    return if admin? || account.users.where(role: "admin").where.not(id: id).exists?

    errors.add(:role, "cannot change: the account needs at least one admin")
  end

  def ensure_not_last_admin
    return unless admin? && !account.users.where(role: "admin").where.not(id: id).exists?

    errors.add(:base, "The last admin cannot be removed")
    throw :abort
  end
end
