# Serves a prompt version (by its Langfuse label, "candidate" by default) to a share of the traffic, so a change
# reaches some workspaces first and its scores can be compared with production before everyone gets it.
# unit "workspace": the same workspaces keep the candidate (a stable hash of prompt and workspace); unit "request":
# each request draws anew. Langfuse.traced applies it at the root of every request. Managed with
# bin/rails prompts:rollout, prompts:promote and prompts:rollback (docs/EVALS.md).
class PromptRollout < ApplicationRecord
  Error = Class.new(StandardError)

  UNITS = %w[workspace request].freeze

  validates :prompt_name, inclusion: { in: Prompt::NAMES }, uniqueness: true
  validates :label, presence: true, exclusion: { in: [ Prompt::LABEL ] }
  validates :share, numericality: { only_integer: true, in: 0..100 }
  validates :unit, inclusion: { in: UNITS }

  # The label per prompt for this workspace's request, for Prompt.using: {"product-agent" => "candidate"}
  def self.versions_for(account)
    where(share: 1..).select { |rollout| rollout.serves?(account) }.to_h { |rollout| [ rollout.prompt_name, rollout.label ] }
  end

  # The candidate becomes production for everyone and the rollout ends. The replaced version is kept for rollback.
  # Returns [replaced production version, new production version].
  def self.promote!(name, label: "candidate")
    candidate = Prompt::Langfuse.fetch(name, label).version
    production = Prompt::Langfuse.fetch(name, Prompt::LABEL).version
    raise Error, "#{name}: the version labeled #{label} (v#{candidate}) is already production" if candidate == production

    # Labels are unique across versions, so this moves production to the candidate's version
    relabel(name, candidate, [ Prompt::LABEL, label ])
    find_or_initialize_by(prompt_name: name).update!(label: label, share: 0, previous_version: production)
    Prompt.refresh
    [ production, candidate ]
  end

  # Undoes the last step: after a promotion, the replaced version is production again; during a rollout, the
  # candidate stops getting traffic. Returns what happened, for the terminal.
  def self.rollback!(name)
    rollout = find_by(prompt_name: name)
    if rollout&.previous_version
      relabel(name, rollout.previous_version, [ Prompt::LABEL ])
      restored = rollout.previous_version
      rollout.update!(share: 0, previous_version: nil)
      Prompt.refresh
      "#{name}: v#{restored} is production again"
    elsif rollout&.share&.positive?
      rollout.update!(share: 0)
      "#{name}: rollout stopped, everyone gets production"
    else
      raise Error, "#{name}: nothing to roll back (no rollout and no promotion)"
    end
  end

  def self.relabel(name, version, labels)
    Langfuse.request(Net::HTTP::Patch, "/api/public/v2/prompts/#{ERB::Util.url_encode(name)}/versions/#{version}", { newLabels: labels })
  end

  def serves?(account)
    bucket = unit == "workspace" ? Zlib.crc32("#{prompt_name}:#{account.id}") % 100 : SecureRandom.random_number(100)
    bucket < share
  end
end
