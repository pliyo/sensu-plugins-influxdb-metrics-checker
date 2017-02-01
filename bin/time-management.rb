class TimeManagement
  TODAY_START_PERIOD = 5
  YESTERDAY_START_PERIOD = 1445 # starts counting 1445 minutes before now() [ yesterday - 5 minutes] to match with today_query_for_a_period start_period

  def today_start_period
    TODAY_START_PERIOD
  end

  def yesterday_start_period
    YESTERDAY_START_PERIOD
  end

  def period_seconds(a_given_day_period)
    a_given_day_period * 60
  end

  def period_epoch(time, a_given_period)
    period = time - period_seconds(a_given_period)
    epoch_time(period)
  end

  def epoch_time(time)
    time.to_i.to_s
  end
end
