check_json
==========

Nagios/Icinga2 plugin to check JSON attributes via http(s).

This Plugin is a fork of the existing JSON Plugin from https://github.com/c-kr/check_json with the enhancements of using the Monitoring::Plugin Perl Module, allowing to use thresholds and performance data collection from various json attributes, and of https://github.com/jiririedl/check_json supporting X-Auth and Bearer Token authorization methods. Performance data is also enhanced to extract performance data compliant to Nagios and Graphite standards. One attribute is selected for thresholds check, multiple others can be added for extracting performance data. This plugin is aimed at simplifying Nagios, Icinga & Icinga2 polling of JSON status APIs.

This particular fork allows to check for dates in the JSON. The date is compared against the current time and the difference in seconds is used as attribute.
Also perfvars and outputvars is fixed for more easy access, just as it was implemented for attributes.

**This fork will also (when implemented) allow you to specify an array of valid values (int or String) for the critical / warning / normal values. This will change the interpretation of --critical and --warning to arrays of valid values (values delimited by ';'). Single values can still be given as before and are interpreted as before. A new parameter will be added (--normal) which will work the same as --warning or --critical.**

## Usage: 
```
check_json 
    -u|--url <URL> 
    -a|--attribute <attribute> 
    [ -c|--critical <integer threshold/array of valid values> ] 
    [ -w|--warning <integer threshold/array of valid values> ] 
    [ -n|--normal <array of valid values> ] 
    [ -e|--expect <value>] 
    [ -p|--perfvars <fields> ] 
    [ -o|--outputvars <fields> ] 
    [ -t|--timeout <timeout> ] 
    [ -d|--divisor <divisor> ] 
    [ -m|--metadata ] 
    [ -T|--contenttype <content-type> ] 
    [ --ignoressl ] 
    [ -x|--xauth <X-Auth-Token> ] 
    [ -b|--bearer <Bearer-Token> ] 
    [ -A|--hattrib <value> ] 
    [ -C|--hcon <value> ] 
    [--isdate] 
    [ -h|--help ]
```

## Valid Argument combinations:

### Check a string/integer value with --expect
COMMAND BASE: `./check_json.pl -u URL <COMMAND SUFFIX>` 
| TYPE            | COMMAND SUFFIX                                            | URL_RESPONSE                                             | RES  |
| --------------- | --------------------------------------------------------- | -------------------------------------------------------- | ---- |
| Single          | -a '{status}' --expect "ok"                               | '{"status":"ok"}'                                        | OK   |
| Single          | -a '{errors}' --expect "0"                                | '{"errors":"0"}'                                         | OK   |
| Multiple        | -a '{status},{patched}' --expect "ok"                     | '{{"status":"ok"},{"patched":"ok"}'                      | OK   |
| Single Nested   | -a '{status}->{server}' --expect "ok"                     | '{"status":{"server":"ok"}}'                             | OK   |
| Multiple Nested | -a '{status}->{server},{status}->{gateway}' --expect "ok" | '{"status":{"server":"ok"},{"gateway":"ok"}}'            | OK   |
| Single          | -a '{status}' --expect "ok"                               | '{"status":"anything else"}'                             | CRIT |
| Multiple        | -a '{status},{patched}' --expect "ok"                     | '{{"status":"anything else"},{"patched":"ok"}'           | CRIT |
| Multiple        | -a '{status},{errors}' --expect "ok"                      | '{{"status":"ok"},{"errors":"0"}'                        | CRIT |
| Multiple        | -a '{status},{patched}' --expect "ok"                     | '{{"status":"ok"},{"patched":"anything else"}'           | CRIT |
| Single Nested   | -a '{status}->{server}' --expect "ok"                     | '{"status":{"server":"anything else"}}'                  | CRIT |
| Multiple Nested | -a '{status}->{server},{status}->{gateway}' --expect "ok" | '{"status":{"server":"anything else"},{"gateway":"ok"}}' | CRIT |
| Multiple Nested | -a '{status}->{server},{status}->{gateway}' --expect "ok" | '{"status":{"server":"ok"},{"gateway":"anything else"}}' | CRIT |

### Check a integer value with thresholds
COMMAND BASE: `./check_json.pl -u URL <COMMAND SUFFIX>`
| TYPE            | COMMAND SUFFIX                                              | URL_RESPONSE                                             | RES  |
| --------------- | ----------------------------------------------------------- | -------------------------------------------------------- | ---- |
| Single          | -a '{connections}' --warning 10 --critical 20               | '{"connections":"9"}'                                    | OK   |
| Single          | -a '{connections}' --warning 10 --critical 20               | '{"connections":"10"}'                                   | WARN |
| Single          | -a '{connections}' --warning 10 --critical 20               | '{"connections":"19"}'                                   | WARN |
| Single          | -a '{connections}' --warning 10 --critical 20               | '{"connections":"20"}'                                   | CRIT |
| Multiple        | -a '{connections},{sessions}' -w 10 -c 20                   | '{"connections":"9"},{"sessions":"8"}'                   | OK   |
| Multiple        | -a '{connections},{sessions}' -w 10 -c 20                   | '{"connections":"9"},{"sessions":"11"}'                  | WARN |
| Multiple        | -a '{connections},{sessions}' -w 10 -c 20                   | '{"connections":"22"},{"sessions":"12"}'                 | CRIT |
| Single Nested   | -a '{connections}->{last_5_min}' -w 10 -c 20                | '{"connections":{"last_5_min":"5"}}'                     | OK   |
| Single Nested   | -a '{connections}->{last_5_min}' -w 10 -c 20                | '{"connections":{"last_5_min":"30"}}'                    | CRIT |
| Multiple Nested | -a '{load}->{last_5_min},{load}->{last_1_min}' -w 3 -c 4    | '{"load":{"last_5_min":"0.5"},{"last_1_min":"1.0"}}'     | OK   |
| Multiple Nested | -a '{load}->{last_5_min},{load}->{last_1_min}' -w 3 -c 4    | '{"load":{"last_5_min":"0.5"},{"last_1_min":"5.0"}}'     | CRIT |

### Check a string/integer value with array of valid values
COMMAND BASE: `./check_json.pl -u URL <COMMAND SUFFIX>`
| TYPE            | COMMAND SUFFIX                                                   | URL_RESPONSE                                        | RES  |
| --------------- | ---------------------------------------------------------------- | --------------------------------------------------- | ---- |
| Single          | -a '{status}' -n "ok" -w "init;warn" -c "err"                    | '{"status":"ok"}'                                   | OK   |
| Single          | -a '{status}' -n "ok" -w "init;warn" -c "err"                    | '{"status":"init"}'                                 | WARN |
| Single          | -a '{status}' -n "ok" -w "init;warn" -c "err"                    | '{"status":"warn"}'                                 | WARN |
| Single          | -a '{status}' -n "ok" -w "init;warn" -c "err"                    | '{"status":"err"}'                                  | CRIT |
| Multiple        | -a '{status},{patches}' -n "ok" -w "warn;available" -c "err;sec" | '{{"status":"ok"},{"patches":"ok"}}'                | OK   |
| Multiple        | -a '{status},{patches}' -n "ok" -w "warn;available" -c "err;sec" | '{{"status":"ok"},{"patches":"available"}}          | WARN |
| Multiple        | -a '{status},{patches}' -n "ok" -w "warn;available" -c "err;sec" | '{{"status":"warn"},{"patches":"ok"}}'              | WARN |
| Multiple        | -a '{status},{patches}' -n "ok" -w "warn;available" -c "err;sec" | '{{"status":"ok"},{"patches":"sec"}}'               | CRIT |
| Multiple        | -a '{status},{patches}' -n "ok" -w "warn;available" -c "err;sec" | '{{"status":"err"},{"patches":"available"}}'        | CRIT |
| Single Nested   | -a '{status}->{patches}' -n "ok" -w "available" -c "sec"         | '{"status":{"patches":"ok"}}'                       | OK   |
| Single Nested   | -a '{status}->{patches}' -n "ok" -w "available" -c "sec"         | '{"status":{"patches":"available"}}'                | WARN |
| Single Nested   | -a '{status}->{patches}' -n "ok" -w "available" -c "sec"         | '{"status":{"patches":"sec"}}'                      | CRIT |
| Multiple Nested | -a '{srv}->{www},{srv}->{mail}' -n "ok" -w "warn" -c "err"       | '{"srv":{"www":"ok"},{"mail":"ok"}}'                | OK   |
| Multiple Nested | -a '{srv}->{www},{srv}->{mail}' -n "ok" -w "warn" -c "err"       | '{"srv":{"www":"ok"},{"mail":"err"}}'               | CRIT |
| Multiple Nested | -a '{srv}->{www},{srv}->{mail}' -n "ok" -w "warn" -c "err"       | '{"srv":{"www":"warn"},{"mail":"ok"}}'              | WARN |

### Check a string/integer value with array of valid values and thresholds
_The threshold of a value is only calculated if it is not equal to any valid value of the other kinds (normal and/or warning and/or critical)_
_The threshold definition of a result (normal/warning/critical) must be the first in an array of valid values_
COMMAND BASE: `./check_json.pl -u URL <COMMAND SUFFIX>`
| TYPE            | COMMAND SUFFIX                                                   | URL_RESPONSE                                        | RES  |
| --------------- | ---------------------------------------------------------------- | --------------------------------------------------- | ---- |
| Single          | -a '{updates}' -n "ok" -w "5" -c "10"                            | '{"updates":"ok"}'                                  | OK   |
| Single          | -a '{updates}' -n "ok" -w "5" -c "10"                            | '{"updates":"0"}'                                   | OK   |
| Single          | -a '{updates}' -n "ok" -w "5" -c "10"                            | '{"updates":"3"}'                                   | OK   |
| Single          | -a '{updates}' -n "ok" -w "5" -c "10"                            | '{"updates":"6"}'                                   | WARN |
| Single          | -a '{updates}' -n "ok" -w "5" -c "10"                            | '{"updates":"6"}'                                   | CRIT |
| Single          | -a '{updates}' -n "ok" -w "5" -c "10;err"                        | '{"updates":"err"}'                                 | CRIT |
**Other types also possible but redacted to short the readme, see above**

##Other Examples

### Date Example
Using divisor 3600 allows to set warning und critical in the perspective of hours.
```
./check_json.pl -u https://some.thing/event -a "{items}[0]->{modifiedAt}" --warning 24 --critical 48 -divisor 3600 --isdate -o "{items}[0]->{modifiedAt}"
```
Result:
```
Check JSON status API OK - modifiedAt: 2021-08-31T13:47:07.341Z
```

### Example with several checks in one:
```
./check_json.pl -u https://some.thing/event -a "{items}[0]->{modifiedAt},{'pagination:page'}->{totalCount}" -w 24,10: -c 48,1: -d 3600 --isdate 1,0 -o "{items}[0]->{modifiedAt},{'pagination:page'}->{totalCount}"
```
Results:
```
Check JSON status API OK - modifiedAt: 2021-08-31T13:47:07.341Z, totalCount: 351
```

### Classical Example

Example: 
```
./check_json.pl --url http://192.168.5.10:9332/local_stats --attribute '{shares}->{dead_shares}' --warning :5 --critical :10 --perfvars '{shares}->{dead_shares},{shares}->{live_shares},{clients}->{clients_connected}'
```

Result:
```
Check JSON status API OK - dead_shares: 2, live_shares: 12, clients_connected: 234 | dead_shares=2;5;10 live_shares=12 clients_connected=234
```

### Auth and Bearer

Home Assistant Check API Status
```
./check_json.pl --url http://hass.lan:8123/api/ --attribute '{message}' --expect 'API running.' --bearer LONG_LIVED_ACCESS_TOKEN
```

Home Assistant Check Entity Status
```
./check_json.pl --url http://hass.lan:8123/api/states/sensor.living_room_temperature --attribute '{state}' --warning 75 --critical 85 --bearer LONG_LIVED_ACCESS_TOKEN
```

Requirements
============

Perl JSON package

* Debian / Ubuntu : libjson-perl libmonitoring-plugin-perl libwww-perl libdatetime-format-iso8601-perl

Icinga2 Integration
===================

Example CheckCommand Definition:
```
/*
 * JSON Check Command
 */
object CheckCommand "check-json" {
  import "plugin-check-command"

  command = [ PluginDir + "/check_json.pl" ]

  arguments = {
    "-u" = {
      required = true
      value = "$json_url$"
    }
    
    "-a" = {
      required = true
      value = "$json_attributes$"
    }

    "-d" = "$json_divisor$"
    "-w" = "$json_warning$"
    "-c" = "$json_critical$"
    "-n" = "$json_normal$"
    "-e" = "$json_expect$"

    "-p" = "$json_perfvars$"
    "-o" = "$json_outvars$"

    "-m" = "$json_metadata$"

    "--isdate" = {
      set_if = "$json_isdate$"
      description = "Handles the attribute as a datetime and computes the time difference to the current datetime."
    }

    "--ignoressl" = {
      set_if = "$json_ignoressl$"
      description = "Ignore bad SSL certificates"
    }

    "-x" = {
      value = "$json_xauth_token$"
      description = "Add an X-Auth-Token header with the specified token"
    }

    "-b" = {
      value = "$json_bearer_token$"
      description = "Add an Authorization: Bearer header with the specified token"
    }
  }
}
```

Example Service Check Definition:
```
/*
 * Home Assistant API Check
 */
object Service "hass-api" {
  host_name = "hass.lan"
  check_command = "check-json"
  
  vars.json_url = "http://$address$:8123/api/"
  vars.json_attributes = "{message}"
  vars.json_expect = "API running."

  vars.json_bearer_token = "LONG_LIVED_ACCESS_TOKEN"
}
```
