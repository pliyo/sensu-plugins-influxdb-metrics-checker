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
         default: 10

  def filter_by_environment_when_needed
    config[:tag].nil? && config[:filter].nil? ? '' : " AND \"#{config[:tag]}\" =~ /#{config[:filter]}/"
  end

  def base_query
    "SELECT sum(\"value\") from "
  end

  def base_query_with_metricname
    base_query + clean_quotes_when_regex
  end

  def clean_quotes_when_regex
    metric = " \"#{config[:metric]}\""
    clean_metric = ''
    if metric.include?('/')
      clean_metric = metric.tr '\"', ''
      @is_using_regex = true
    else
      clean_metric = metric
    end

    clean_metric
  end

  def today_query_for_a_period
    start_period = 5; # starts counting 5 minutes before now() to let influxdb time to aggregate the data
    end_period = config[:period] + 5; # adds 5 minutes to match with start_period
    query = query_for_a_period(start_period, end_period)
    query + filter_by_environment_when_needed
  end

  def yesterday_query_for_a_period
    start_period = 1445; # starts counting 1445 minutes before now() [ yesetrday - 5 minutes] to match with today_query_for_a_period start_period
    end_period = config[:period] + 1445; # adds 1445 minutes to match with start_period
    query = query_for_a_period(start_period, end_period)
    query + filter_by_environment_when_needed
  end

  def query_for_a_period(start_period, end_period)
    query = base_query_with_metricname + ' WHERE time > now() - ' + end_period.to_s + 'm AND time < now() - ' + start_period.to_s + 'm'
    query + filter_by_environment_when_needed
  end

  def encode_parameters(parameters)
    encodedparams = Addressable::URI.escape(parameters)

    if @is_using_regex
      encode_for_regex = encodedparams.gsub! '+', '%2B'
    else
      encode_for_regex = encodedparams
    end

    "#{config[:db]}&q=" + encode_for_regex
  end

  def yesterday_query_encoded
    query = yesterday_query_for_a_period
    encode_parameters(query)
  end

  def today_query_encoded
    query = today_query_for_a_period
    encode_parameters(query)
  end

  def today_value
    response = request(today_query_encoded)
    metrics = parse_json(response)
    @today_metric_count = count_metrics(metrics)
    series = read_series_of_metrics(metrics)
    @today_metrics = store_metrics(series)
    read_values_of_series(series)
  end

  def yesterday_value
    response = request(yesterday_query_encoded)
    metrics = parse_json(response)
    @yesterday_metric_count = count_metrics(metrics)
    series = read_series_of_metrics(metrics)
    @yesterday_metrics = store_metrics(series)
    read_values_of_series(series)
  end

  def count_metrics(metrics)
    if metrics[0]['series'].nil?
      0
    else
      metrics[0]['series'].count
    end
  end

  def parse_json(response)
    JSON.parse(response.to_str)['results']
  end

  def read_values_of_series(series)
    values = series[0]['values'][0][1]
    values.to_f
  end

  def read_series_of_metrics(metrics)
    if metrics[0]['series'].nil?
      puts 'No results coming from InfluxDB. Please check your query'
      nil
    else
      metrics[0]['series']
    end
  end

  def store_metrics(series)
    regex_metrics = Hash.new()
    if series.count > 0
      series.each do |values|
        value = values['values'][0][1]
        key = values['name']
        value_float = value.to_f

        regex_metrics[key] = value_float
      end
      regex_metrics
    end
  end

  def display_metrics
    @yesterday_metrics.each do |key, value|
      puts key
      puts value
    end
    @today_metrics.each do |key, value|
      puts key
      puts value
    end
  end

  def calculate_percentage_ofdifference(original, newnumber)
    if @is_using_regex
      difference_for_regex
    else
      difference_between_two_metrics(original, newnumber)
    end
  end

  def difference_for_regex
    if @today_metric_count >= @yesterday_metric_count
      0
    else
      -100 # different or more number of metrics could be a problem. Regex is designed to catch exceptions, so more exceptions -> alert
    end
  end

  def difference_between_two_metrics(original, newnumber)
    decrease = original - newnumber
    decrease.to_f / original.to_f * 100
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

  def evaluate_percentage_and_notify(difference)
    if difference < config[:crit]
      critical "\"#{config[:metric]}\" difference is below allowed minimum of #{config[:crit]} %"
    elsif difference < config[:warn]
      warning "\"#{config[:metric]}\" difference is below warn threshold of #{config[:warn]}"
    else
      ok 'metrics count ok'
    end
  end

  def calculate_difference_and_display_result(today, yesterday)
    difference = calculate_percentage_ofdifference(today, yesterday)
    puts 'Difference of: ' + difference.round(5).to_s + ' %  for a period of ' + config[:period].to_s + 'm'
    evaluate_percentage_and_notify(difference)
  end

  def run
    today = today_value
    yesterday = yesterday_value
    if today.nil? && yesterday.nil?
      puts 'Please revisit your query'
    else
      calculate_difference_and_display_result(today, yesterday)
    end
  exit

  rescue Errno::ECONNREFUSED => e
    critical 'InfluxDB is not responding' + e.message
  rescue RestClient::RequestTimeout
    critical 'InfluxDB Connection timed out'
  rescue StandardError => e
    unknown 'An exception occurred: ' + e.message
  end
end
