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
    "SELECT sum(\"value\") from \"#{config[:metric]}\" "
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
    query = base_query + ' WHERE time > now() - ' + end_period.to_s + 'm AND time < now() - ' + start_period.to_s + 'm'
    query + filter_by_environment_when_needed
  end

  def encode_parameters(parameters)
    encodedparams = Addressable::URI.escape(parameters)
    "#{config[:db]}&q=" + encodedparams
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
    second_query = today_query_encoded
    response_to_compare = request(second_query)
    read_metrics(response_to_compare)
  end

  def yesterday_value
    query = yesterday_query_encoded
    response = request(query)
    read_metrics(response)
  end

  def read_metrics(response)
    metrics = JSON.parse(response.to_str)['results']
    series = metrics[0]['series']
    values = series[0]['values'][0][1]

    if values.nil?
      values = 0
    end

    values.to_f
  end

  def calculate_percentage_ofdifference(original, newnumber)
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

  def run
    difference = calculate_percentage_ofdifference(today_value, yesterday_value)
    puts 'Difference of: ' + difference.to_s + ' %   for a period of ' + config[:period].to_s + 'm'
    evaluate_percentage_and_notify(difference)

  rescue Errno::ECONNREFUSED => e
    critical 'InfluxDB is not responding' + e.message
  rescue RestClient::RequestTimeout
    critical 'InfluxDB Connection timed out'
  rescue StandardError => e
    unknown 'An exception occurred:' + e.message
  end
end
