Change Log
This project adheres to [Semantic Versioning](http://semver.org/).

This CHANGELOG follows the format listed at [Keep A Changelog](http://keepachangelog.com/)

# [0.3.3] - 2017-01-17
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
[0.3.2]: https://github.com/pliyosenpai/sensu-plugins-influxdb-metrics-checker/0.3.2...0.3.3
[0.3.3]: https://github.com/pliyosenpai/sensu-plugins-influxdb-metrics-checker/0.3.3...HEAD
