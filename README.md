# sensu-plugins-influxdb-metrics-checker

[ ![Build Status](https://travis-ci.org/pliyosenpai/sensu-plugins-influxdb-metrics-checker.svg?branch=master)](https://travis-ci.org/pliyosenpai/sensu-plugins-influxdb-metrics-checker)
[![Gem Version](https://badge.fury.io/rb/sensu-plugins-influxdb-metrics-checker.svg)](http://badge.fury.io/rb/sensu-plugins-influxdb-metrics-checker.svg)

## Background story
As soon as we started using InfluxDB we were wondering how we could read a given metric, compare it to its previous days, evaluate the percentage of difference, and act according to it.

We chose to do it as a Sensu plugin because it comes with Handlers that will allow us to extend the usability of this information, such as sending a message to slack, or sending an alert to OpsGenie.

The result is that now we are able to experiment with our metrics and alerts, giving us a better understanding of whats going on in our systems.

## What it does
The script will compare the values of yesterday at this time minus 10 minutes, with the values of today at this time minus 10 minus.
It will calculate the percentage of difference and will act on that.
You will be able set a threshold of warning and critical values where your program will act.

## Components
There is just one script that you can find at
 * bin/check-influxdb-metrics.rb

## Getting started

At the moment there is just one script
**check-influxdb-metrics** which you can run in a bash doing:

```
ruby check-influxdb-metrics.rb --host=metrics-influxdb.internal.com --port=8086 --user=admin --password=password -c -3 -w -10 --db=statsd_metrics --metric=api.request.counter
```

Once in Sensu:
```
/opt/sensu/embedded/bin$ /opt/sensu/embedded/bin/ruby check-influxdb-metrics.rb --host=metrics-influxdb.internal.com --port=8086 --user=admin --password=password -c -3 -w -10 --db=statsd_metrics --metric=api.request.counter
```

If you have a tag you can filter your metrics by doing, for example:
```
ruby check-influxdb-metrics.rb --host=metrics-influxdb.service.veinternal.com --port=8086 --user=admin --password=password -c -20 -w -10 --db=statsd_metrics --metric=datareceivers.request.counter --tag=datacenter --filter=ci

```

## Lessons learnt
The InfluxDb query language that we used is not the latest, you can find it here:

[InfluxDb query language](https://docs.influxdata.com/influxdb/v0.10/query_language/)

What matters for this program is that:
**When doing a query**:
```
-24h will turn into bad request
- 24h good
```

**When passing parameters**
```
-c=-3 Will be transform as 0.0.
-c -3 counts as a number
```

## Installation

[Installation and Setup](http://sensu-plugins.io/docs/installation_instructions.html)

## Notes
The ruby executables are install in path similar to `/opt/sensu/embedded/lib/ruby/gems/2.0.0/gems/sensu-plugins-storm-0.1.0/bin`
