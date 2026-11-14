namespace :evals do
  desc "Run the demo dataset (config/evals) on a model and print accuracy: TASK=extraction|matching (default both), MODEL=oxybot-haiku"
  task run: :environment do
    account = Account.find_by(name: "Acme Analytics") or abort "Needs the demo workspace: bin/rails db:seed"
    model = ENV.fetch("MODEL", "oxybot-haiku")
    tasks = ENV["TASK"] ? [ ENV["TASK"] ] : Evaluation::TASKS

    tasks.each do |task|
      evaluation = Evaluation.new(task: task, model: model, account: account)
      results = evaluation.run
      results.each { |result| puts "  #{result.correct ? "ok  " : "MISS"} #{result.id}#{"  expected #{result.expected}, got #{result.actual}" unless result.correct}" }
      puts format("%s with %s: %d of %d right (%.0f%%)%s", task, model, results.count(&:correct), results.size,
                  Evaluation.accuracy(results) * 100, Langfuse.configured? ? "; Langfuse experiment \"#{evaluation.run_name}\"" : "")
    end
  end
end
