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

  def encodeParameters(parameters)
    encodedparams = Addressable::URI.escape(parameters)
    query = "#{config[:db]}&q=" + encodedparams
    return query
  end

  def getYesterdayQuery()
    query = "SELECT sum(\"value\") from " + "\"#{config[:metric]}\"" + " WHERE time > now() - 48h AND time < now() - 24h"
    return query
  end

  def getTodayQuery()
    query = "SELECT sum(\"value\") from " + "\"#{config[:metric]}\"" + " WHERE time > now() - 24h"
    return query
  end

  def yesterdayQueryEncoded()
    query = getYesterdayQuery()
    queryEncoded = encodeParameters(query)
    return queryEncoded
  end

  def todayQueryEncoded()
    query = getTodayQuery()
    queryEncoded = encodeParameters(query)
    return queryEncoded
  end

  def readMetrics(response)
    metrics = JSON.parse(response.to_str)['results']
    series = metrics[0]['series']
    values = series[0]['values'][0][1]

    if values == nil then
      values = 0
    end

    return values.to_f
  end

  def getPercentage(original, newnumber)
    decrease = original - newnumber
    decreasedPercentage = ( decrease.to_f / original.to_f ) * 100
  end

  def request(path)
    protocol = 'http'
    auth = Base64.encode64("#{config[:user]}:#{config[:pass]}")
    url = "#{protocol}://#{config[:host]}:#{config[:port]}/query?db=#{path}"
    RestClient::Request.execute(
      method: :get,
      url: url,
      timeout: config[:timeout],
      headers: { 'Authorization' => "Basic #{auth}" }
    )
  end

  def run
    metric = "\"#{config[:metric]}\""
    query = yesterdayQueryEncoded()
    response = request(query)
    yesterdayValue = readMetrics(response)
    puts "Yesterday's Data"
    puts yesterdayValue

    secondQuery = todayQueryEncoded()
    responseToCompare = request(secondQuery)
    todayValue = readMetrics(responseToCompare)
    puts "Today's data!!!"
    puts todayValue

    difference = getPercentage(todayValue, yesterdayValue)
    puts difference

    if difference < config[:crit]
      critical "\"#{config[:metric]}\" sum is below allowed minimum of #{config[:crit]} %"
    elsif difference < config[:warn]
      warning "\"#{config[:metric]}\" sum is below warn threshold of #{config[:warn]}"
    else
      ok "metrics count ok"
    end

  rescue Errno::ECONNREFUSED => e
    critical 'InfluxDB is not responding' + e.message
  rescue RestClient::RequestTimeout
    critical 'InfluxDB Connection timed out'
  rescue StandardError => e
    unknown 'An exception occurred:' + e.message
  end
end
