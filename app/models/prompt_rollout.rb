# Serves a prompt version (by its Langfuse label, "candidate" by default) to a share of the traffic, so a change
# reaches some workspaces first and its scores can be compared with production before everyone gets it.
# unit "workspace": the same workspaces keep the candidate (a stable hash of prompt and workspace); unit "request":
# each request draws anew. Langfuse.traced applies it at the root of every request. Managed with
# bin/rails prompts:rollout; promoting the candidate to production ends it.
class PromptRollout < ApplicationRecord
  UNITS = %w[workspace request].freeze

  validates :prompt_name, inclusion: { in: Prompt::NAMES }, uniqueness: true
  validates :label, presence: true, exclusion: { in: [ Prompt::LABEL ] }
  validates :share, numericality: { only_integer: true, in: 0..100 }
  validates :unit, inclusion: { in: UNITS }

  # The label per prompt for this workspace's request, for Prompt.using: {"product-agent" => "candidate"}
  def self.versions_for(account)
    where(share: 1..).select { |rollout| rollout.serves?(account) }.to_h { |rollout| [ rollout.prompt_name, rollout.label ] }
  end

  def serves?(account)
    bucket = unit == "workspace" ? Zlib.crc32("#{prompt_name}:#{account.id}") % 100 : SecureRandom.random_number(100)
    bucket < share
  end
end
