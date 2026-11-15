# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

# Evaluations, prompt rollouts and the Langfuse setup call LiteLLM and Langfuse, so they read .env like bin/dev does.
# It must happen before Rails boots, because the model and Langfuse addresses are read at boot.
if Rake.application.top_level_tasks.any? { |task| task.start_with?("evals:", "prompts:", "langfuse:") }
  require_relative "lib/boot/env_file"
  EnvFile.load(File.expand_path(".env", __dir__))
end

require_relative "config/application"

Rails.application.load_tasks
