Change Log
This project adheres to [Semantic Versioning](http://semver.org/).

This CHANGELOG follows the format listed at [Keep A Changelog](http://keepachangelog.com/)

# [0.6.1] - 2017-02-03
Aiming to fix a problem with 0.6.0 where a library was not included.
It uses absolute time in epoch seconds instead of relative time (now)

# [0.6.0] - 2017-02-01
- eleventh release
Using absolute time in `epoch seconds` instead of relative time `now`.
This version is not working because it's missing a library, please don't use it.

# [0.5.0] - 2017-01-24
- tenth release
Changing from Percentage of Difference to Percentage of Change.

# [0.4.8] - 2017-01-24
- ninth release
Bug fix when values comes as null. Now they will become zero.

# [0.4.4] - 2017-01-20
- eight release
Small fix when printing numbers

# [0.4.0] - 2017-01-20
- seventh release
New feature: Triangulation. Added the ability to get percentage of metric A, get percentage of metric B, and compare the distance between them. Useful when the metrics are related together by some business rule.
Improved feedback when returning to customer.

# [0.3.4] - 2017-01-17
- sixth release
Allow the usage of regex expressions that we can identify as "/^[your_regex]$". I'll strongly recommend to use this only for exceptions, and always aim for zero-exceptions, or it wouldn't be accurate. At the moment it will fire when the number of exception today is bigger than the number of exceptions yesterday.
Also, if you have the same number of metrics found (let's say, exceptions) it will compare just the first one. I'll not rely on this tool (yet) for a deep analysis of differences in exceptions.
Improve feedback when returning null from InfluxDB (usually because the query is pointing to a metric that doesn't exists).

# [0.3.2] - 2016-12-14
### Added
- fifth release
Rounded float result to 5 decimal places

# [0.3.0] - 2016-11-21
### Added
- fourth release
Added the possibility to tweak your queries by adding --period in your parameters.
By default --period will be 10 minutes to work with previous versions

# [0.2.1] - 2016-11-21
### Added
- third release
Fixing refactor

# [0.2.0] - 2016-11-21
### Added
- second release
Added the possibility to use tag and filter.
Querying from the past 10 minutes vs Yesterday in the past 10 minutes.
Leaving 5 minutes to the data to consolidate.

# [0.1.0] - 2016-11-17
### Added
- initial release

[0.1.0]: https://github.com/pliyosenpai/sensu-plugins-influxdb-metrics-checker/0.1.0...0.2.0
[0.2.0]: https://github.com/pliyosenpai/sensu-plugins-influxdb-metrics-checker/0.2.0...0.2.1
[0.2.1]: https://github.com/pliyosenpai/sensu-plugins-influxdb-metrics-checker/0.2.1...0.3.0
[0.3.0]: https://github.com/pliyosenpai/sensu-plugins-influxdb-metrics-checker/0.3.0...0.3.2
[0.3.2]: https://github.com/pliyosenpai/sensu-plugins-influxdb-metrics-checker/0.3.2...0.3.4
[0.3.4]: https://github.com/pliyosenpai/sensu-plugins-influxdb-metrics-checker/0.3.4...0.4.0
[0.4.0]: https://github.com/pliyosenpai/sensu-plugins-influxdb-metrics-checker/0.4.0...0.4.4
[0.4.4]: https://github.com/pliyosenpai/sensu-plugins-influxdb-metrics-checker/0.4.4...0.4.8
[0.4.8]: https://github.com/pliyosenpai/sensu-plugins-influxdb-metrics-checker/0.4.8...0.5.0
[0.5.0]: https://github.com/pliyosenpai/sensu-plugins-influxdb-metrics-checker/0.5.0...0.6.0
[0.6.0]: https://github.com/pliyosenpai/sensu-plugins-influxdb-metrics-checker/0.6.0...0.6.1
[0.6.1]: https://github.com/pliyosenpai/sensu-plugins-influxdb-metrics-checker/0.6.1...HEAD
