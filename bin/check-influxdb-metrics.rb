#!/usr/bin/env ruby
# Check a given metric and compare it to its values in the past
# to produce health status

require 'sensu-plugin/check/cli'
require 'rest-client'
require 'openssl'
require 'uri'
require 'json'
require 'base64'
require 'addressable/uri'
require './time-management'

class CheckInfluxDbMetrics < Sensu::Plugin::Check::CLI
  option :host,
         short: '-h',
         long: '--host=VALUE',
         description: 'Cluster host',
         required: true

  option :port,
         short: '-p',
         long: '--port=VALUE',
         description: 'Api port',
         required: true

  option :user,
         short: '-u',
         long: '--username=VALUE',
         description: 'username',
         required: true

  option :pass,
         short: '-p',
         long: '--password=VALUE',
         description: 'password',
         required: true

  option :ssl,
         description: 'use HTTPS (default false)',
         long: '--ssl'

  option :crit,
         short: '-c',
         long: '--critical=VALUE',
         description: 'Critical threshold',
         required: true,
         proc: proc { |l| l.to_f }

  option :warn,
         short: '-w',
         long: '--warn=VALUE',
         description: 'Warn threshold',
         required: true,
         proc: proc { |l| l.to_f }

  option :timeout,
         short: '-t',
         long: '--timeout=VALUE',
         description: 'Timeout in seconds',
         proc: proc { |l| l.to_f },
         default: 5

  option :db,
         short: '-d',
         long: '--db=VALUE',
         description: 'Default DB'

  option :metric,
         short: '-m',
         long: '--metric=VALUE',
         description: 'Metric to influx DB. Ex datareceivers.messages.count'

  option :tag,
         long: '--tag=VALUE',
         description: 'Filter by tag if provided.'

  option :filter,
         short: '-f',
         long: '--filter=VALUE',
         description: 'Set the name of your filter, for example: `datacenter`'

  option :period,
         long: '--period=VALUE',
         description: 'Filter by a given day period in minutes',
         proc: proc { |l| l.to_i },
         default: 20

  option :triangulate,
         long: '--triangulate=VALUE',
         description: 'Triangulate with this metric'

  option :applyfilterbothqueries,
         long: '--applyfilterbothqueries=VALUE',
         description: 'Set if you want to apply tag and filter also for the query that you are about to triangulate with'

  option :distance,
         long: '--distance=VALUE',
         description: 'Set the distance threshold to alert in case of triangulation',
         default: 2

  BASE_QUERY = 'SELECT sum("value") from '.freeze
  TIME_MANAGER = TimeManagement.new

  def today_start_period
    TIME_MANAGER.period_epoch(Time.now, TIME_MANAGER.today_start_period)
  end

  def yesterday_start_period
    TIME_MANAGER.period_epoch(Time.now, TIME_MANAGER.yesterday_start_period)
  end

  def yesterday_end_period
    decrease = config[:period] + TIME_MANAGER.yesterday_start_period
    TIME_MANAGER.period_epoch(Time.now, decrease)
  end

  def today_end_period
    decrease = config[:period] + TIME_MANAGER.today_start_period
    TIME_MANAGER.period_epoch(Time.now, decrease)
  end

  def epoch_time(time)
    time.to_i.to_s
  end

  def base_query_with_metricname(metric)
    BASE_QUERY + clean_quotes_when_regex(metric)
  end

  def clean_quotes_when_regex(metric_to_clean)
    metric = ' "' + metric_to_clean + '"'
    clean_metric = ''
    if metric.include?('/')
      clean_metric = metric.tr '\"', ''
      @is_using_regex = true
    else
      clean_metric = metric
    end

    clean_metric
  end

  def filter_by_environment_when_needed
    config[:tag].nil? && config[:filter].nil? ? '' : " AND \"#{config[:tag]}\" =~ /#{config[:filter]}/"
  end

  def filter_for_triangulate_when_needed
    config[:applyfilterbothqueries].nil? ? '' : " AND \"#{config[:tag]}\" =~ /#{config[:filter]}/"
  end

  def query_for_a_period_timespan(metric, start_period, end_period, istriangulated)
    query = base_query_with_metricname(metric) + ' WHERE time > ' + end_period.to_s + 's AND time < ' + start_period.to_s + 's'
    query + add_filter_when_needed(istriangulated)
  end

  def add_filter_when_needed(istriangulated)
    if istriangulated == true
      filter_for_triangulate_when_needed
    else
      filter_by_environment_when_needed
    end
  end

  def query_encoded_for_a_period(metric, start_period, end_period, istriangulated)
    query = query_for_a_period_timespan(metric, start_period, end_period, istriangulated)
    encode_parameters(query)
  end

  def metrics(metric, start_period, end_period, istriangulated)
    query = query_encoded_for_a_period(metric, start_period, end_period, istriangulated)
    response = request(query) # puts response if debugging and what to know whats going on
    parse_json(response)
  end

  def encode_parameters(parameters)
    encodedparams = Addressable::URI.escape(parameters)
    # this is needed after encoding because Addressable will not encode +. So for ex: ([A-Za-z0-9-]+) will miss the + and with that it will not find the metrics
    encode_for_regex = if @is_using_regex
                         encodedparams.gsub! '+', '%2B'
                       else
                         encodedparams
                       end

    "#{config[:db]}&q=" + encode_for_regex
  end

  def today_metrics
    today_info = metrics(config[:metric], today_start_period, today_end_period, false)
    @today_metric_count = validate_metrics_and_count(today_info)
    if @today_metric_count > 0
      series = read_series_from_metrics(today_info)
      @today_metrics = store_metrics(series)
      read_value_from_series(series)
    else
      0
    end
  end

  def yesterday_metrics
    yesterday_info = metrics(config[:metric], yesterday_start_period, yesterday_end_period, false)
    @yesterday_metric_count = validate_metrics_and_count(yesterday_info)
    if @yesterday_metric_count > 0
      series = read_series_from_metrics(yesterday_info)
      @yesterday_metrics = store_metrics(series)
      read_value_from_series(series)
    else
      0
    end
  end

  def today_triangulated_metrics
    today_triangulated_info = metrics(config[:triangulate], today_start_period, today_end_period, true)
    @today_triangulated_metric_count = validate_metrics_and_count(today_triangulated_info)
    if @today_triangulated_metric_count > 0
      series = read_series_from_metrics(today_triangulated_info)
      @today_triangulated_metrics = store_metrics(series)
      read_value_from_series(series)
    else
      0
    end
  end

  def yesterday_triangulated_metrics
    yesterday_triangulated_info = metrics(config[:triangulate], yesterday_start_period, yesterday_end_period, true)
    @yesterday_triangulated_metric_count = validate_metrics_and_count(yesterday_triangulated_info)
    if @yesterday_triangulated_metric_count > 0
      series = read_series_from_metrics(yesterday_triangulated_info)
      @yesterday_triangulated_metrics = store_metrics(series)
      read_value_from_series(series)
    else
      0
    end
  end

  def read_series_from_metrics(metrics)
    metrics[0]['series']
  end

  def validate_metrics_and_count(metrics)
    if metrics.empty? || metrics.nil? || metrics[0].nil? || metrics[0]['series'].nil?
      if metrics[0]['series'].nil?
        0
      else
        metrics[0]['series'][0]['values'][0][1] || 0
      end
    else
      metrics[0]['series'].count
    end
  end

  def parse_json(response)
    JSON.parse(response.to_str)['results']
  end

  def read_value_from_series(series)
    if series.nil?
      0
    elsif series[0]['values'][0][1].nil?
      0
    else
      values = series[0]['values'][0][1]
      values.to_f
    end
  end

  def store_metrics(series)
    regex_metrics = Hash.new {}
    if series.nil? == false && series.count > 0
      series.each do |values|
        value = values['values'][0][1]
        regex_metrics[values['name']] = value.to_f
      end
      regex_metrics
    end
  end

  def display_metrics
    puts 'Today metrics analysis: '
    @today_metrics.each do |key, value|
      puts 'For: ' + key + ' : ' + value.to_s
    end
  end

  def difference_for_regex_and_notify
    # different or more number of metrics for today could be a problem. Regex is designed to catch exceptions, so more exceptions -> alert
    if @today_metric_count == 0 && @yesterday_metric_count == 0
      ok 'no metrics found'
    elsif @today_metric_count > @yesterday_metric_count
      display_metrics
      critical 'For ' + config[:metric] + ' more metrics tracked today (' + @today_metric_count.to_s + ') than yesterday (' + @yesterday_metric_count.to_s + ')'
    elsif @today_metric_count == @yesterday_metric_count
      compare_each_metric_in_regex
    else
      ok 'regex seems ok! Today metrics dropped. Yesterday (' + @yesterday_metric_count.to_s + ') vs (' + @today_metric_count.to_s + ') found today.'
    end
  end

  def difference_for_standard_queries(today, yesterday)
    difference = difference_between_two_metrics(yesterday, today)
    evaluate_percentage_and_notify(difference)
  end

  def difference_for_regex_queries(today, yesterday)
    difference = difference_between_two_metrics(yesterday, today)
    evaluate_percentage_for_regex(difference)
  end

  def compare_each_metric_in_regex
    @today_metrics.each do |today_key, today_value|
      @yesterday_metrics.each do |yesterday_key, yesterday_value|
        iterate_through_each_value_in_regex(today_key, today_value, yesterday_key, yesterday_value)
      end
    end
    ok 'all regex metrics seems fine'
  end

  def iterate_through_each_value_in_regex(today_key, today_value, yesterday_key, yesterday_value)
    if today_key.eql? yesterday_key
      puts yesterday_value.to_s + ' vs ' + today_value.to_s + ' for ' + today_key
      if today_value > yesterday_value
        difference_for_regex_queries(today_value, yesterday_value)
      end
    else
      warn 'new metric found: ' + today_key
    end
  end

  # percentage difference calculator (deprecated)
  def previous_difference_between_two_metrics(original, newnumber)
    decrease = original - newnumber
    decrease.to_f / original.to_f * 100
  end

  # percentage of change
  def difference_between_two_metrics(yesterday, today)
    decrease = today.to_f - yesterday.to_f
    division = decrease.to_f / yesterday.to_f.abs
    division.to_f * 100.to_f
  end

  def request(path)
    protocol = config[:ssl] ? 'https' : 'http'
    auth = Base64.encode64("#{config[:user]}:#{config[:pass]}")
    url = "#{protocol}://#{config[:host]}:#{config[:port]}/query?db=#{path}"
    RestClient::Request.execute(
      method: :get,
      url: url,
      timeout: config[:timeout],
      headers: { 'Authorization' => "Basic #{auth}" }
    )
  end

  def evaluate_percentage_for_regex(difference)
    puts 'Difference of: ' + difference.round(3).to_s + ' %  for a period of ' + config[:period].to_s + 'm'
    if difference > config[:crit]
      critical "\"#{config[:metric]}\" difference is above allowed minimum of #{config[:crit]} %"
    elsif difference > config[:warn]
      warning "\"#{config[:metric]}\" difference is above warn threshold of #{config[:warn]}"
    else
      puts 'this metric seems ok'
    end
  end

  def evaluate_percentage_and_notify(difference)
    puts 'Difference of: ' + difference.round(3).to_s + ' %  for a period of ' + config[:period].to_s + 'm'
    if difference < config[:crit]
      critical "\"#{config[:metric]}\" difference is below allowed minimum of #{config[:crit]} %"
    elsif difference < config[:warn]
      warning "\"#{config[:metric]}\" difference is below warn threshold of #{config[:warn]}"
    else
      ok 'metrics count ok'
    end
  end

  def evaluate_distance_and_notify(distance)
    if distance > config[:distance].to_f
      puts 'distance of ' + distance.round(3).to_s
      critical config[:metric] + ' vs ' + config[:triangulate] + ' distance is greater than allowed minimum of ' + config[:distance].to_s
    else
      ok 'distance ok'
    end
  end

  def calculate_difference_and_display_result(today, yesterday)
    if @is_using_regex
      difference_for_regex_and_notify
    else
      difference_between_two_metrics(yesterday, today)
    end
  end

  def difference_between_percentages_of_two_metrics
    validate_base_metrics
    validate_triangulated_metrics
    base = difference_between_two_metrics(yesterday_metrics, today_metrics)
    triangulated = difference_between_two_metrics(yesterday_triangulated_metrics, today_triangulated_metrics)
    puts 'difference for ' + config[:metric] + ' ' + base.round(3).to_s + '% vs ' + config[:triangulate] + ' ' + triangulated.round(3).to_s + '%'
    distance = distance_between_two_numbers(base, triangulated)
    evaluate_distance_and_notify(distance)
  end

  def distance_between_two_numbers(a, b)
    (a - b).abs
  end

  def validate_triangulated_metrics
    today = today_triangulated_metrics
    yesterday = yesterday_triangulated_metrics
    if today.nil? && yesterday.nil?
      puts 'No metrics found to triangulate'
      exit
    else
      0
    end
  end

  def validate_base_metrics
    today = today_metrics
    yesterday = yesterday_metrics
    if today.nil? && yesterday.nil?
      puts 'No metrics found in base to triangulate'
      exit
    else
      0
    end
  end

  def difference_between_metrics
    today = today_metrics
    yesterday = yesterday_metrics
    if today.nil? && yesterday.nil?
      puts 'No results coming from InfluxDB either for Today nor Yesterday. Please check your query or try again'
    else
      difference = calculate_difference_and_display_result(today, yesterday)
      evaluate_percentage_and_notify(difference)
    end
    exit
  end

  def triangulation?
    config[:triangulate].nil?
  end

  def check_metrics_in_influxdb
    if triangulation?
      difference_between_metrics
    else
      difference_between_percentages_of_two_metrics
    end
  end

  def run
    check_metrics_in_influxdb

  rescue Errno::ECONNREFUSED => e
    critical 'InfluxDB is not responding' + e.message
  rescue RestClient::RequestTimeout
    critical 'InfluxDB Connection timed out'
  rescue StandardError => e
    unknown 'An exception occurred: ' + e.message
  end
end
