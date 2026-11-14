# Gradual prompt rollouts (docs/EVALS.md). Every task takes NAME (the prompt) and, where it applies, LABEL (the
# Langfuse label of the candidate version, "candidate" by default).
namespace :prompts do
  def prompt_name
    ENV.fetch("NAME") { abort "Set NAME, one of #{Prompt::NAMES.join(", ")}" }.tap do |name|
      abort "Unknown prompt #{name}; one of #{Prompt::NAMES.join(", ")}" unless Prompt::NAMES.include?(name)
    end
  end

  def prompt_version(name, label)
    Prompt::Langfuse.fetch(name, label).version
  rescue Prompt::Langfuse::Error
    nil
  end

  desc "Show each prompt's production and candidate versions and its rollout"
  task status: :environment do
    abort "Set LANGFUSE_URL, LANGFUSE_PUBLIC_KEY and LANGFUSE_SECRET_KEY first" unless Langfuse.configured?

    Prompt::NAMES.each do |name|
      rollout = PromptRollout.find_by(prompt_name: name)
      label = rollout&.label || "candidate"
      candidate = prompt_version(name, label)
      parts = [ "production v#{prompt_version(name, Prompt::LABEL) || "?"}" ]
      parts << "#{label} v#{candidate}" if candidate
      parts << "#{rollout.share}% of #{rollout.unit}s on #{label}" if rollout&.share&.positive?
      parts << "rollback restores v#{rollout.previous_version}" if rollout&.previous_version
      puts "#{name}: #{parts.join(", ")}"
    end
  end

  desc "Serve the candidate to a share of traffic: NAME=product-agent SHARE=10 [BY=workspace|request] [LABEL=candidate]; SHARE=0 stops it"
  task rollout: :environment do
    rollout = PromptRollout.find_or_initialize_by(prompt_name: prompt_name)
    rollout.assign_attributes(share: ENV.fetch("SHARE") { abort "Set SHARE, 0 to 100" }, unit: ENV.fetch("BY", rollout.unit), label: ENV.fetch("LABEL", rollout.label))
    abort rollout.errors.full_messages.to_sentence unless rollout.save

    version = prompt_version(rollout.prompt_name, rollout.label)
    puts "#{rollout.prompt_name}: #{rollout.share}% of #{rollout.unit}s get the version labeled #{rollout.label} (#{version ? "v#{version}" : "not in Langfuse, production is served"})"
  end

  desc "Make the candidate production for everyone and end its rollout: NAME=product-agent [LABEL=candidate]"
  task promote: :environment do
    abort "Set LANGFUSE_URL, LANGFUSE_PUBLIC_KEY and LANGFUSE_SECRET_KEY first" unless Langfuse.configured?

    replaced, promoted = PromptRollout.promote!(prompt_name, label: ENV.fetch("LABEL", "candidate"))
    puts "#{ENV["NAME"]}: v#{promoted} is production (was v#{replaced}); undo with bin/rails prompts:rollback NAME=#{ENV["NAME"]}"
  rescue PromptRollout::Error => e
    abort e.message
  end

  desc "Undo the last step: restore the production version a promotion replaced, or stop a rollout: NAME=product-agent"
  task rollback: :environment do
    abort "Set LANGFUSE_URL, LANGFUSE_PUBLIC_KEY and LANGFUSE_SECRET_KEY first" unless Langfuse.configured?

    puts PromptRollout.rollback!(prompt_name)
  rescue PromptRollout::Error => e
    abort e.message
  end
end
