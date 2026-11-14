namespace :langfuse do
  desc "Upload config/prompts (text and config) to Langfuse as new versions labeled production; NAME=product-agent LABEL=candidate " \
       "uploads one prompt as a candidate to roll out gradually (bin/rails prompts:rollout)"
  task push_prompts: :environment do
    abort "Set LANGFUSE_URL, LANGFUSE_PUBLIC_KEY and LANGFUSE_SECRET_KEY first" unless Prompt::Langfuse.configured?

    label = ENV.fetch("LABEL", Prompt::LABEL)
    (ENV["NAME"] ? [ ENV["NAME"] ] : Prompt::NAMES).each do |name|
      abort "Unknown prompt #{name}" unless Prompt::NAMES.include?(name)
      file = Prompt.from_file(name)
      version = Prompt::Langfuse.create(name, file.text, config: file.config, labels: [ label ])["version"]
      puts "#{name}: version #{version} (#{label})"
    end
    Prompt.refresh
  end

  desc "Register every skill in Langfuse, so its Skills view can show where each one is used"
  task push_skills: :environment do
    abort "Set LANGFUSE_URL, LANGFUSE_PUBLIC_KEY and LANGFUSE_SECRET_KEY first" unless Langfuse.configured?

    Skill.find_each do |skill|
      Skill::Tracing.publish(skill)
      puts "#{skill.langfuse_name}: version #{skill.langfuse_version}"
    end
  end

  desc "Connect Langfuse to LiteLLM and set up OxyBot's evaluators (safe to run again)"
  task setup: :environment do
    abort "Set LANGFUSE_URL, LANGFUSE_PUBLIC_KEY and LANGFUSE_SECRET_KEY first" unless Langfuse.configured?

    Langfuse::Setup.run
  end
end
