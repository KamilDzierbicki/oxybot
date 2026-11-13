# A sample repository on disk (config/mocks/github) searched with plain word matching.
class Integration::Github::MockClient
  ROOT = Rails.root.join("config/mocks/github")

  def search_code(query)
    words = query.to_s.downcase.scan(/[[:alnum:]]{3,}/)
    files.filter_map do |path|
      text = File.read(ROOT.join(path))
      score = words.count { |word| text.downcase.include?(word) }
      next if score.zero?

      line = text.lines.find { |candidate| words.any? { |word| candidate.downcase.include?(word) } }.to_s
      [ score, { path: path, snippet: line.strip } ]
    end.sort_by { |score, _hit| -score }.map(&:last)
  end

  def read_file(path)
    full = ROOT.join(path).cleanpath
    raise ArgumentError, "outside the repository" unless full.to_s.start_with?("#{ROOT}/") && full.file?

    File.read(full)
  end

  private

  def files
    Dir.glob("**/*", base: ROOT).select { |path| ROOT.join(path).file? }.sort
  end
end
