require_relative "simple_number"
require "test/unit"

class CheckInfluxDbMetricsTests < Test::Unit::TestCase

  def test_simple
    assert_equal("a", CheckInfluxDbMetrics.encodeParameters("a") )
  end

end
