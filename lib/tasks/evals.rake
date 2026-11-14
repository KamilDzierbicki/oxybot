namespace :evals do
  desc "Measure the AI steps on config/evals: TASK=extraction|matching|retrieval|documents (default all), MODEL=oxybot-haiku, " \
       "PROMPT=candidate or a version number (of each task's prompt), RAG=rrf_k=30,text_weight=0.5"
  task run: :environment do
    account = Account.find_by(name: "Acme Analytics") or abort "Needs the demo workspace: bin/rails db:seed"
    model = ENV.fetch("MODEL", "oxybot-haiku")
    tasks = ENV["TASK"] ? ENV["TASK"].split(",") : Evaluation::TASKS
    prompt = ENV["PROMPT"].presence&.then { |value| value.match?(/\A\d+\z/) ? value.to_i : value }
    retrieval = ENV["RAG"].to_s.split(",").to_h { |pair| pair.split("=", 2).map(&:strip) }

    tasks.each do |task|
      evaluation = Evaluation.new(task: task, model: model, account: account, prompt: prompt, retrieval: retrieval)
      results = evaluation.run
      results.each { |result| puts "  #{result.correct ? "ok  " : "MISS"} #{result.id}#{"  expected #{result.expected}, got #{result.actual}" unless result.correct || task == "documents"}" }
      averages = Evaluation.averages(results).except("correct").map { |name, value| "#{name} #{value}" }
      puts format("%s with %s: %d of %d right (%.0f%%)%s%s", task, evaluation.variant.except("retrieval").values.join(", "), results.count(&:correct), results.size, Evaluation.accuracy(results) * 100,
                  averages.any? ? "; #{averages.join(", ")}" : "", Langfuse.configured? ? "; Langfuse experiment \"#{evaluation.run_name}\"" : "")
    end
  end

  desc "Make the demo workspace ready for evaluations: embed features and insights, extract unprocessed feedback"
  task prepare: :environment do
    account = Account.find_by(name: "Acme Analytics") or abort "Needs the demo workspace: bin/rails db:seed"
    account.features.where(embedding: nil).find_each(&:embed)
    account.feedback_notes.where(processed_at: nil).find_each(&:extract_insights)
    Insight.embed_all(account.insights.where(embedding: nil).to_a)
    puts "#{account.features.count} features, #{account.insights.count} insights ready"
  end

  desc "Run the tasks of config/evals/baseline.yml and fail when a score drops below its minimum (the CI Evals job)"
  task check: :environment do
    account = Account.find_by(name: "Acme Analytics") or abort "Needs the demo workspace: bin/rails db:seed"
    baseline = Evaluation::Baseline.new
    averages = baseline.tasks.keys.to_h do |task|
      [ task, Evaluation.averages(Evaluation.new(task: task, model: baseline.model, account: account).run) ]
    end
    rows = baseline.compare(averages)
    rows.each { |row| puts format("%-4s %-10s %-20s %6s (minimum %s)", row.passed? ? "ok" : "DROP", row.task, row.score, row.value || "none", row.minimum) }
    failed = rows.reject(&:passed?)
    abort "#{failed.size} score(s) below the baseline in config/evals/baseline.yml" if failed.any?
  end
end
