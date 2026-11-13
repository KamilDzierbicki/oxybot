require "test_helper"

class Document::DiffTest < ActiveSupport::TestCase
  test "marks added, removed and unchanged lines in order" do
    diff = Document::Diff.new("a\nb\nc", "a\nc\nd")

    assert_equal [ [ :same, "a" ], [ :removed, "b" ], [ :same, "c" ], [ :added, "d" ] ], diff.lines.map { |line| [ line.change, line.text ] }
    assert_equal 1, diff.added_count
    assert_equal 1, diff.removed_count
  end

  test "identical texts have no changes" do
    assert_not Document::Diff.new("same", "same").changed?
  end
end
