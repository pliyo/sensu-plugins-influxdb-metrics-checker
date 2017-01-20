# sensu-plugins-influxdb-metrics-checker

[ ![Build Status](https://travis-ci.org/pliyosenpai/sensu-plugins-influxdb-metrics-checker.svg?branch=master)](https://travis-ci.org/pliyosenpai/sensu-plugins-influxdb-metrics-checker)
[![Gem Version](https://badge.fury.io/rb/sensu-plugins-influxdb-metrics-checker.svg)](https://rubygems.org/gems/sensu-plugins-influxdb-metrics-checker)

## Background story
As soon as we started using InfluxDB we were wondering how we could read a given metric, compare it to its previous days, evaluate the percentage of difference, and act according to it.

We chose to do it as a Sensu plugin because it comes with Handlers that will allow us to extend the usability of this information, such as sending a message to slack, or sending an alert to OpsGenie.

The result is that now we are able to experiment with our metrics and alerts, giving us a better understanding of whats going on in our systems.

## What it does
The script will compare the values of yesterday at this time minus 25 minutes, with the values of today at this time minus 25 minus.
It will calculate the percentage of difference and will act on that.
You will be able to set a threshold of warning and critical values where your program will act.
It will also leave it 10 minutes to aggregate the data in influxdb, so we are more precise.

## Components
There is just one script that you can find at
 * bin/check-influxdb-metrics.rb

## Getting started

Once we go to **check-influxdb-metrics** you can run it in a bash doing:

```
ruby check-influxdb-metrics.rb --host=metrics-influxdb.internal.com --port=8086 --user=admin --password=password -c -3 -w -10 --db=statsd_metrics --metric=api.request.counter
```

Once in Sensu:
```
/opt/sensu/embedded/bin$ /opt/sensu/embedded/bin/ruby check-influxdb-metrics.rb --host=metrics-influxdb.internal.com --port=8086 --user=admin --password=password -c -3 -w -10 --db=statsd_metrics --metric=api.request.counter
```

If you have a tag you can filter your metrics by doing, for example:
```
ruby check-influxdb-metrics.rb --host=metrics-influxdb.internal.com --port=8086 --user=admin --password=password -c -20 -w -10 --db=statsd_metrics --metric=api.request.counter --tag=datacenter --filter=ci

```

You can set the period that you want for your queries, for example:
```
ruby check-influxdb-metrics.rb --host=metrics-influxdb.internal.com --port=8086 --user=admin --password=password -c -20 -w -10 --db=statsd_metrics --metric=api.request.counter --tag=datacenter --filter=ci --period=1440

```

## Advanced Queries

**Regex**

You can use it in your metrics. The spirit behind this feature is to gather information about exceptions only, beware that this could gather all your metrics inside your influxdb cluster, which may produce some unintended pain, so always aiming for querying exceptions, and ideally a zero exception policy.
I'll strongly advise against using it for other purposes.

**How it works**

1. It will understand that is a regex only when the metric name contains '/'. In the bash you'll need to include your metric inside double quotes.
2. It will compare the number of metrics gathered today vs the number of metrics gathered yesterday.
3. If today we read more than yesterday, it will blow up as **Critical**.
4. If today we read the same number of metrics than yesterday, at the moment it will compare only the first one.
I'll not rely on this tool (yet) for a deep analysis of differences when comparing multiple metrics (such as exceptions) using Regex.
```
ruby check-influxdb-metrics.rb --host=metrics-influxdb.internal.com --port=8086 --user=admin --password=password -c -20 -w -10 --db=statsd_metrics --metric="/^prefix.datacenter.([A-Za-z0-9-]+).([A-Za-z0-9-]+).exceptions$/"

```

**Triangulation**

In trigonometry and geometry, [triangulation](https://en.wikipedia.org/wiki/Triangulation) is the process of determining the location of a point by forming triangles to it from known points. This feature of the script is inspired in that idea.

[![triangulation_01.png](https://s24.postimg.org/kjihvilvp/triangulation_01.png (2KB))](https://postimg.org/image/hcnybw1fl/)

Once we have a given metric A (ex: messages.sent), we'll normally compare that to yesterday's weather A', we'll get the percentage of difference (X in the picture) and according to our threshold we'll fire an alert. Cool. Now let's go one step further.
We may have a metric B (ex: sessions.generated), that has a business dependency on A. And if we dig further in our metrics, we may discover that, let's say, for every 5 metrics in A we have 1 in B. (In this example, let's say that you'll need 5 messages sent to build 1 session).

If we could say that every 5 As relates to 1 B, then the % of difference for A (X in the picture) and the percentage of difference for B (Y in the picture) will always be the same
```
Ex: A' = 15500, A = 20500, X = 32.26%. B' = 3100, B = 4100, Y =  32.26%
```
Realistically, it's not always like that in production applications, sometimes you may need 7 messages, others only 4, so your average would be something around 5.333. Therefore, we can't say that the % in difference will always be the same, but once we look at the *distance* between these percentages (C in the picture), we'll see that they are pretty close. And that's the spirit of it, the ability to diagnose when the distance is higher than expected.

A more real example will be:

```
A' = 15500, A = 20500, X = 32.26%. B' = 3081, B = 4134, Y =  34.18%. So C (distance) = 1.92
```

Let's say that the system that sends items has an increase of 150%, and you are using this tool to verify that, therefore you don't get any exceptions because there is no drop in the metrics, but the system that process sessions keeps in the same 2% increase, which is a big distance up to 148. We clearly have a problem here. Maybe some bottleneck is happening somewhere, maybe some messages are lost due to this huge increase, and hopefully this feature will allow you to identify that something fussy is going on.

**How it works**

This query will get the distance between "messages.counter" % vs "sessions.generated" %. By default it's set to fire an alert if that turns out to be bigger than 2.

```
ruby check-influxdb-metrics.rb --host=metrics-influxdb.internal.com --port=8086 --user=admin --password=password -c -30 -w -10 --db=statsd_metrics --metric=messages.counter --triangulate=sessions.generated
```
If you want to increase the distance, you will just need --distance.

```
ruby check-influxdb-metrics.rb --host=metrics-influxdb.internal.com --port=8086 --user=admin --password=password -c -30 -w -10 --db=statsd_metrics --metric=messages.counter --triangulate=sessions.generated --distance=10
```

If you want to apply some tags and filters you can do it as you'll do normally, just bear in mind that by default they will not apply to both metrics, only tot he first one. If you want to apply them to the second metric you'll just need to add --applyfilterbothqueries=yes

```
ruby check-influxdb-metrics.rb --host=metrics-influxdb.internal.com --port=8086 --user=admin --password=password -c -30 -w -10 --db=statsd_metrics --metric=messages.counter --tag=datacenter --filter=pro-westeurope --triangulate=sessions.generated --distance=10 --applyfilterbothqueries=yes
```

## Lessons learnt
The InfluxDb query language that we used is not the latest, you can find it here:

[InfluxDb query language](https://docs.influxdata.com/influxdb/v0.10/query_language/)

What matters for this program is that:
**When doing a query**:
```
-24h will turn into bad request
- 24h good

- session.certified will turn into a bad request
- "session.certified" is good. Notice that when you use grafana or influx db console you don't need the quotes
 but when you query through the script you'll need them.
 When using regex both with and without quotes will work, because what matters is `/^[metric]$/`
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
