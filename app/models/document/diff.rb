# Line diff of two texts (longest common subsequence), for reviewing suggestions and versions.
class Document::Diff
  Line = Data.define(:change, :text) # change: :same, :added or :removed

  def initialize(before, after)
    @before = before.to_s.lines.map(&:chomp)
    @after = after.to_s.lines.map(&:chomp)
  end

  def lines
    @lines ||= build
  end

  def changed? = lines.any? { |line| line.change != :same }
  def added_count = lines.count { |line| line.change == :added }
  def removed_count = lines.count { |line| line.change == :removed }

  private

  def build
    table = lcs_table
    result = []
    i, j = 0, 0
    while i < @before.size && j < @after.size
      if @before[i] == @after[j]
        result << Line.new(:same, @before[i])
        i += 1
        j += 1
      elsif table[i + 1][j] >= table[i][j + 1]
        result << Line.new(:removed, @before[i])
        i += 1
      else
        result << Line.new(:added, @after[j])
        j += 1
      end
    end
    @before[i..].each { |text| result << Line.new(:removed, text) }
    @after[j..].each { |text| result << Line.new(:added, text) }
    result
  end

  # table[i][j]: length of the longest common subsequence of before[i..] and after[j..]
  def lcs_table
    table = Array.new(@before.size + 1) { Array.new(@after.size + 1, 0) }
    (@before.size - 1).downto(0) do |i|
      (@after.size - 1).downto(0) do |j|
        table[i][j] = @before[i] == @after[j] ? table[i + 1][j + 1] + 1 : [ table[i + 1][j], table[i][j + 1] ].max
      end
    end
    table
  end
end
