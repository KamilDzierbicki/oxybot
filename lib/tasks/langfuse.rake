namespace :langfuse do
  desc "Upload config/prompts to Langfuse as new versions labeled production (edit them in Langfuse afterwards)"
  task push_prompts: :environment do
    abort "Set LANGFUSE_URL, LANGFUSE_PUBLIC_KEY and LANGFUSE_SECRET_KEY first" unless Prompt::Langfuse.configured?

    Prompt::NAMES.each do |name|
      version = Prompt::Langfuse.create(name, Prompt.from_file(name).text, labels: [ Prompt::LABEL ])["version"]
      puts "#{name}: version #{version}"
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
