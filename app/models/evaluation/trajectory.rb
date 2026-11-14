# Scores the tool calls of one assistant turn against the expected trajectory (config/evals/tools.yml):
# - tool_choice: every required tool was called, and nothing outside required and allowed
# - arguments: share of argument expectations met by some call of that tool
# - within_steps: no more tool calls than max_steps
# - steps: the number of tool calls
class Evaluation::Trajectory
  def initialize(calls, expected)
    @calls = Array(calls).map { |call| call.to_h.stringify_keys }
    @expected = expected
  end

  def scores
    { "tool_choice" => tool_choice? ? 1 : 0, "arguments" => arguments.round(3), "within_steps" => within_steps? ? 1 : 0, "steps" => @calls.size }
  end

  def correct? = tool_choice? && arguments == 1.0 && within_steps?

  private

  def called = @calls.map { |call| call["name"] }.uniq
  def required = Array(@expected["tools"])

  def tool_choice?
    (required - called).empty? && (called - required - Array(@expected["allowed"])).empty?
  end

  def within_steps? = @calls.size <= @expected.fetch("max_steps", 3)

  def arguments
    expectations = @expected.fetch("arguments", {}).flat_map { |tool, arguments| arguments.map { |name, want| [ tool, name, want ] } }
    return 1.0 if expectations.empty?

    met = expectations.count do |tool, name, want|
      @calls.any? { |call| call["name"] == tool && matches?(call.dig("arguments", name) || call.dig("arguments", name.to_sym), want) }
    end
    met.fdiv(expectations.size)
  end

  # A list: the value contains one of the words. A string: the value equals it. Case does not matter.
  def matches?(value, want)
    value = value.to_s.downcase
    want.is_a?(Array) ? want.any? { |word| value.include?(word.to_s.downcase) } : value == want.to_s.downcase
  end
end
