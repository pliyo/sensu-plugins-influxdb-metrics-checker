# sensu-plugins-influxdb
Plugin to retrieve metrics and evaluate them. Aiming to track outages.

Example of use:

ruby check-influxdb-metrics.rb --host=metrics-influxdb.internal.com --port=8086 --user=admin --password=password -c -3 -w -10 --db=statsd_metrics --metric=api.request.counter

Important things to now about InfluxDB:

When doing a query, writing:
-24h is wrong
- 24h is right

Important things to now about passing parameters in Ruby:
-c=-3 Will be transform as 0.0. While -c -3 counts as a float
