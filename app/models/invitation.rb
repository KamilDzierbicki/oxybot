# An invitation to join an account. The link carries a random token; only its digest is stored.
class Invitation < ApplicationRecord
  VALID_FOR = 7.days

  belongs_to :account
  belongs_to :invited_by, class_name: "User"

  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :role, inclusion: { in: User::ROLES }
  validate :email_not_taken, on: :create

  scope :open, -> { where(accepted_at: nil).where(expires_at: Time.current..) }

  attr_reader :token

  before_validation on: :create do
    @token = SecureRandom.urlsafe_base64(32)
    self.token_digest = self.class.digest(@token)
    self.expires_at ||= VALID_FOR.from_now
  end

  def self.digest(token) = Digest::SHA256.hexdigest(token.to_s)

  def self.find_open_by_token(token)
    open.find_by(token_digest: digest(token)) if token.present?
  end

  # Creates the user and closes the invitation; returns the user (with errors if invalid)
  def accept(name:, password:)
    transaction do
      user = account.users.create(name: name, password: password, email_address: email, role: role)
      update!(accepted_at: Time.current) if user.persisted?
      user
    end
  end

  private

  def email_not_taken
    errors.add(:email, "already has an OxyBot account") if User.exists?(email_address: email)
  end
end
