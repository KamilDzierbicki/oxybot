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
end
