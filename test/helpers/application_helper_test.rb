require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "external links accept https only" do
    assert_includes external_link("OXY-1", "https://linear.app/acme/issue/OXY-1"), %(href="https://linear.app/acme/issue/OXY-1")
    assert_equal "OXY-1", external_link("OXY-1", "javascript:alert(1)")
  end

  test "markdown from the model cannot inject HTML, and citations become links" do
    html = markdown("Hi <script>alert(1)</script> [insight:12]")

    assert_not_includes html, "<script>"
    assert_includes html, %(href="/insights/12")
  end
end
