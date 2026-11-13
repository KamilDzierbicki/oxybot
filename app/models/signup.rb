# Creates a new account with its first admin
class Signup
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :account_name, :string
  attribute :name, :string
  attribute :email_address, :string
  attribute :password, :string

  validates :account_name, :name, presence: true
  validates :email_address, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 10 }
  validate :email_free

  attr_reader :user

  def save
    return false unless valid?

    ActiveRecord::Base.transaction do
      account = Account.create!(name: account_name)
      @user = account.users.create!(name: name, email_address: email_address, password: password, role: "admin")
    end
    true
  end

  private

  def email_free
    errors.add(:email_address, "already has an account") if User.exists?(email_address: email_address.to_s.strip.downcase)
  end
end
