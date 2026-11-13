# Creates a new account with its first admin
class Signup
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :account_name, :string
  attribute :name, :string
  attribute :email_address, :string
  attribute :password, :string
  attribute :time_zone, :string # the browser's IANA zone, e.g. "Europe/Warsaw"

  validates :account_name, :name, presence: true
  validates :email_address, format: { with: URI::MailTo::EMAIL_REGEXP }

  def email_address=(value)
    super(value.to_s.strip)
  end
  validates :password, length: { minimum: User::MIN_PASSWORD_LENGTH, maximum: 72 }
  validate :email_free

  attr_reader :user

  def save
    return false unless valid?

    ActiveRecord::Base.transaction do
      account = Account.create!(name: account_name, time_zone: rails_time_zone)
      @user = account.users.create!(name: name, email_address: email_address.to_s.strip, password: password, role: "admin")
    end
    true
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
    errors.add(:email_address, "cannot be used for a new workspace")
    false
  end

  private

  # Schedules and dates follow the zone the person signed up from; unknown zones fall back to UTC
  def rails_time_zone
    ActiveSupport::TimeZone::MAPPING.key(time_zone.to_s) || (ActiveSupport::TimeZone[time_zone.to_s] ? time_zone : "UTC")
  end

  # Deliberately vague, so the form cannot be used to find out who has an account
  def email_free
    errors.add(:email_address, "cannot be used for a new workspace") if User.exists?(email_address: email_address.to_s.strip.downcase)
  end
end
