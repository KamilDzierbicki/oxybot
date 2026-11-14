# The averages of the last run of each task (tmp/evals/<task>.json, kept on this machine), so a run prints how its
# scores moved: "recall_at_5_hybrid 0.82 -> 0.86". The previous run's variant is printed too, because a comparison
# with another model or prompt version means something else than a rerun.
class Evaluation::History
  DIR = Rails.root.join("tmp/evals")

  Run = Data.define(:variant, :at, :averages)

  def initialize(task, dir: DIR)
    @path = Pathname(dir).join("#{task}.json")
  end

  def previous
    return unless @path.exist?

    data = JSON.parse(@path.read)
    Run.new(variant: data["variant"], at: Time.zone.parse(data["at"]), averages: data["averages"])
  rescue JSON::ParserError
    nil
  end

  def record(variant, averages)
    FileUtils.mkdir_p(@path.dirname)
    @path.write(JSON.pretty_generate({ variant: variant, at: Time.current.iso8601, averages: averages }))
  end

  # One line per score: "  mrr_hybrid            0.875 -> 0.925  (+0.050)", or the value alone without a previous run
  def self.lines(averages, previous)
    averages.map do |name, value|
      before = previous&.averages&.[](name)
      next format("  %-20s %.3f", name, value) if before.nil?

      change = value - before
      format("  %-20s %.3f -> %.3f  (%s)", name, before, value, change.zero? ? "same" : format("%+.3f", change))
    end
  end
end
