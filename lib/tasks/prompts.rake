namespace :prompts do
  desc "Serve a prompt's candidate version to a share of traffic: PROMPT=product-agent SHARE=10 [BY=workspace|request] [LABEL=candidate]; SHARE=0 stops it"
  task rollout: :environment do
    rollout = PromptRollout.find_or_initialize_by(prompt_name: ENV.fetch("PROMPT") { abort "Set PROMPT, one of #{Prompt::NAMES.join(", ")}" })
    rollout.assign_attributes(share: ENV.fetch("SHARE") { abort "Set SHARE, 0 to 100" }, unit: ENV.fetch("BY", rollout.unit), label: ENV.fetch("LABEL", rollout.label))
    abort rollout.errors.full_messages.to_sentence unless rollout.save

    version = Prompt.using({ rollout.prompt_name => rollout.label }) { Prompt.fetch(rollout.prompt_name).version }
    puts "#{rollout.prompt_name}: #{rollout.share}% of #{rollout.unit}s get the version labeled #{rollout.label} (#{version ? "v#{version}" : "not in Langfuse, production is served"})"
  end

  desc "List prompt rollouts"
  task rollouts: :environment do
    PromptRollout.order(:prompt_name).each { |rollout| puts "#{rollout.prompt_name}: #{rollout.share}% of #{rollout.unit}s on #{rollout.label}" }
    puts "No rollouts" if PromptRollout.none?
  end

  desc "Make the candidate version production and end its rollout: PROMPT=product-agent [LABEL=candidate]"
  task promote: :environment do
    abort "Set LANGFUSE_URL, LANGFUSE_PUBLIC_KEY and LANGFUSE_SECRET_KEY first" unless Langfuse.configured?

    name = ENV.fetch("PROMPT") { abort "Set PROMPT" }
    label = ENV.fetch("LABEL", "candidate")
    version = Prompt::Langfuse.fetch(name, label).version
    # Labels are unique across versions, so this moves production to the candidate's version
    Langfuse.request(Net::HTTP::Patch, "/api/public/v2/prompts/#{ERB::Util.url_encode(name)}/versions/#{version}", { newLabels: [ Prompt::LABEL, label ] })
    PromptRollout.where(prompt_name: name).update_all(share: 0)
    Prompt.refresh
    puts "#{name}: v#{version} is production; rollout stopped"
  end
end
