require 'test/unit'
require_relative '../lib/time-management'

class TimePeriodTests < Test::Unit::TestCase
  def test_today_start_period
    assert_equal(5, TimeManagement.new.today_start_period)
  end

  def test_yesterday_start_period
    assert_equal(1445, TimeManagement.new.yesterday_start_period)
  end

  def test_start_period_seconds
    a_given_period = 5
    assert_equal(5 * 60, TimeManagement.new.period_seconds(a_given_period))
  end

  def test_epoch_period
    now = Time.now # current time
    time_manager = TimeManagement.new # this is the time that you'll substract from now, to build your period
    today_expected_epoch = time_manager.period_epoch(now, time_manager.today_start_period)

    period = now - time_manager.period_seconds(time_manager.today_start_period)
    expected_result_in_epoch = period.to_i.to_s
    assert_equal(expected_result_in_epoch, today_expected_epoch)
  end
end
