# Evaluations of OxyBot's AI steps on config/evals. The runbook is docs/EVALS.md. Every task takes the same
# variables: TASK (one or more, comma-separated), MODEL (a LiteLLM alias), LABEL or VERSION (the version of the
# task's prompt in Langfuse) and RAG (retrieval parameters, key=value pairs).
namespace :evals do
  def evals_account
    Account.find_by(name: "Acme Analytics") or abort "Needs the demo workspace: bin/rails db:seed"
  end

  def evals_variant
    { prompt: ENV["VERSION"].presence&.to_i || ENV["LABEL"].presence,
      retrieval: ENV["RAG"].to_s.split(",").to_h { |pair| pair.split("=", 2).map(&:strip) } }
  end

  desc "Measure AI steps: TASK=extraction|matching|retrieval|documents|tools|injection (default all, comma-separated) [MODEL=oxybot-haiku] " \
       "[LABEL=candidate or VERSION=4] [RAG=rrf_k=30,text_weight=0.5]"
  task run: :environment do
    model = ENV.fetch("MODEL", "oxybot-haiku")
    tasks = ENV["TASK"] ? ENV["TASK"].split(",") : Evaluation::TASKS

    tasks.each do |task|
      evaluation = Evaluation.new(task: task, model: model, account: evals_account, **evals_variant)
      results = evaluation.run
      results.each { |result| puts "  #{result.correct ? "ok  " : "MISS"} #{result.id}#{"  expected #{result.expected}, got #{result.actual}" unless result.correct || task == "documents"}" }

      label = [ evaluation.variant["model"], evaluation.variant["prompt"], *evaluation.variant.fetch("retrieval", {}).map { |key, value| "#{key}=#{value}" } ].join(" ")
      averages = Evaluation.averages(results)
      history = Evaluation::History.new(task)
      previous = history.previous
      puts format("%s with %s: %d of %d right (%.0f%%)", task, label, results.count(&:correct), results.size, Evaluation.accuracy(results) * 100)
      puts previous ? "  compared with the run of #{previous.at.to_fs(:short)} (#{previous.variant}):" : "  first run on this machine:"
      puts Evaluation::History.lines(averages, previous)
      puts "  Langfuse: dataset oxybot-#{task}, experiment \"#{evaluation.run_name}\"" if Langfuse.configured?
      history.record(label, averages)
    end
  end

  desc "Make the demo workspace ready for evaluations: embed features and insights, extract unprocessed feedback"
  task prepare: :environment do
    account = evals_account
    account.features.where(embedding: nil).find_each(&:embed)
    account.feedback_notes.where(processed_at: nil).find_each(&:extract_insights)
    Insight.embed_all(account.insights.where(embedding: nil).to_a)
    puts "#{account.features.count} features, #{account.insights.count} insights ready"
  end

  # The scores config/evals/baseline.yml lists, measured on its model
  def evals_baseline_run(baseline)
    baseline.tasks.to_h do |task, minimums|
      averages = Evaluation.averages(Evaluation.new(task: task, model: baseline.model, account: evals_account).run)
      [ task, averages.slice(*minimums.keys) ]
    end
  end

  desc "Run the tasks of config/evals/baseline.yml and fail when a score drops below its minimum (the CI Evals job)"
  task check: :environment do
    baseline = Evaluation::Baseline.new
    rows = baseline.compare(evals_baseline_run(baseline))
    rows.each { |row| puts format("%-4s %-10s %-20s %6s (minimum %s)", row.passed? ? "ok" : "DROP", row.task, row.score, row.value || "none", row.minimum) }
    failed = rows.reject(&:passed?)
    abort "#{failed.size} score(s) below the baseline in config/evals/baseline.yml" if failed.any?
  end

  desc "Measure the baseline's tasks and write the results as the new minimums in config/evals/baseline.yml (review the diff)"
  task baseline: :environment do
    baseline = Evaluation::Baseline.new
    measured = evals_baseline_run(baseline)
    measured.each { |task, scores| scores.each { |score, value| puts format("%-10s %-20s %s -> %s", task, score, baseline.tasks.dig(task, score), (value * 100).floor / 100.0) } }
    Evaluation::Baseline::FILE.write(Evaluation::Baseline.text(baseline.model, measured))
    puts "Wrote #{Evaluation::Baseline::FILE.relative_path_from(Rails.root)}; check git diff before committing"
  end
end
