class User < ApplicationRecord
  has_secure_password
  belongs_to :account
  has_many :sessions, dependent: :destroy
  has_many :conversations, dependent: :destroy
  has_many :skills, dependent: :destroy
  # Shared work outlives the person who made it; their invitations do not
  has_many :sent_invitations, class_name: "Invitation", foreign_key: :invited_by_id, dependent: :destroy
  has_many :created_documents, class_name: "Document", foreign_key: :creator_id, dependent: :nullify
  has_many :document_versions, dependent: :nullify
  has_many :document_suggestions, dependent: :nullify

  MIN_PASSWORD_LENGTH = 10

  normalizes :email_address, with: ->(e) { e.strip.downcase }
  normalizes :slack_user_id, :mattermost_user_id, with: ->(id) { id.strip.presence }

  ROLES = %w[admin member].freeze

  validates :name, presence: true
  validates :role, inclusion: { in: ROLES }
  validates :email_address, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: MIN_PASSWORD_LENGTH, maximum: 72 }, allow_nil: true
  validates :slack_user_id, uniqueness: { scope: :account_id }, allow_nil: true
  validates :mattermost_user_id, uniqueness: { scope: :account_id }, allow_nil: true
  validate :account_keeps_an_admin, on: :update

  before_destroy :ensure_not_last_admin

  scope :alphabetically, -> { order(:name, :id) }

  def admin? = role == "admin"

  # A personal token for coding agents (MCP). Only its digest is stored; the token is shown once.
  # After a password change every other way in ends: sessions and the MCP token
  def reset_password(attributes)
    transaction do
      update(attributes) && (sessions.destroy_all; update_column(:mcp_token_digest, nil); true)
    end
  end

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
