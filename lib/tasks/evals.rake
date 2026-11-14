namespace :evals do
  desc "Measure the AI steps on config/evals with a model: TASK=extraction|matching|retrieval|documents (default all), MODEL=oxybot-haiku"
  task run: :environment do
    account = Account.find_by(name: "Acme Analytics") or abort "Needs the demo workspace: bin/rails db:seed"
    model = ENV.fetch("MODEL", "oxybot-haiku")
    tasks = ENV["TASK"] ? ENV["TASK"].split(",") : Evaluation::TASKS

    tasks.each do |task|
      evaluation = Evaluation.new(task: task, model: model, account: account)
      results = evaluation.run
      results.each { |result| puts "  #{result.correct ? "ok  " : "MISS"} #{result.id}#{"  expected #{result.expected}, got #{result.actual}" unless result.correct || task == "documents"}" }
      averages = Evaluation.averages(results).except("correct").map { |name, value| "#{name} #{value}" }
      puts format("%s with %s: %d of %d right (%.0f%%)%s%s", task, model, results.count(&:correct), results.size, Evaluation.accuracy(results) * 100,
                  averages.any? ? "; #{averages.join(", ")}" : "", Langfuse.configured? ? "; Langfuse experiment \"#{evaluation.run_name}\"" : "")
    end
  end
end
