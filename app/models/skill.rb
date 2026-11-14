# A saved workflow for the assistant, run by typing /name in a chat. Team skills (no user) are shared with
# everyone in the account; personal skills win over a team skill of the same name.
class Skill < ApplicationRecord
  belongs_to :account
  belongs_to :user, optional: true

  normalizes :name, with: ->(name) { name.strip.delete_prefix("/").downcase.parameterize }

  validates :name, :description, :instructions, presence: true
  validates :name, uniqueness: { scope: [ :account_id, :user_id ] }

  scope :alphabetically, -> { order(:name) }

  # Registered in Langfuse so its Skills view can count uses; only the name and description leave OxyBot
  after_commit -> { PublishSkillJob.perform_later(self) },
               on: %i[create update], if: -> { Langfuse.configured? && (saved_change_to_name? || saved_change_to_description? || langfuse_version.nil?) }
  scope :available_to, ->(user) { where(account: user.account, user: [ nil, user ]) }

  INVOCATION = %r{\A/([a-z0-9-]+)\b\s*(.*)\z}m

  # "/voc reports" -> [skill, "reports"], or nil when the text names no skill
  def self.invoked_in(text, user)
    name, rest = text.to_s.strip.match(INVOCATION)&.captures
    return unless name

    skill = available_to(user).where(name: name).order(Arel.sql("user_id IS NULL")).first
    [ skill, rest.to_s.strip ] if skill
  end

  def team? = user_id.nil?

  # One Langfuse project serves every workspace, so the name carries the workspace (and the owner of a personal skill)
  def langfuse_name = [ "a#{account_id}", ("u#{user_id}" if user_id), name ].compact.join("-")
end
