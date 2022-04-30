check_json
==========

Nagios/Icinga2 plugin to check JSON attributes via http(s).

This Plugin is a fork of the existing JSON Plugin from https://github.com/c-kr/check_json with the enhancements of using the Monitoring::Plugin Perl Module, allowing to use thresholds and performance data collection from various json attributes, and of https://github.com/jiririedl/check_json supporting X-Auth and Bearer Token authorization methods. Performance data is also enhanced to extract performance data compliant to Nagios and Graphite standards. One attribute is selected for thresholds check, multiple others can be added for extracting performance data. This plugin is aimed at simplifying Nagios, Icinga & Icinga2 polling of JSON status APIs.

This particular fork allows to check for dates in the JSON. The date is compared against the current time and the difference in seconds is used as attribute.
Also perfvars and outputvars is fixed for more easy access, just as it was implemented for attributes.

**This fork will also (when implemented) allow you to specify an array of valid values (int or String) for a critical / warning / normal values. This will be activated via the --isarrayofvalidvalues switch and change the interpretation of --critical and --warning to arrays of valid values. A new parameter will be added (--normal) which will work the same as --warning or --critical but only in combination with --isarrayofvalidvalues. This new option --isarrayofvalidvalues cannot be used in combination with --isdate. Thresholds are not available even when only supplying integers als valid values.**

Usage: 
```
check_json -u|--url <URL> -a|--attribute <attribute> [ -c|--critical <threshold/array of valid values> ] [ -w|--warning <threshold/array of valid values> ] [ -n|--normal <array of valid values> ] [ -p|--perfvars <fields> ] [ -o|--outputvars <fields> ] [ -t|--timeout <timeout> ] [ -d|--divisor <divisor> ] [ -T|--contenttype <content-type> ] [ --ignoressl ] [--isdate] [--isarrayofvalidvalues] [ -h|--help ]
```

### Array of Valid Values Example
```
./check_json.pl -u https://some.rest.api/v3/status -a "{status}" --warning "warn" --critical "err" --normal "ok,init" --isarrayofvalidvalues -o "{status}"
./check_json.pl -u https://some.rest.api/v3/settings -a "{setting_1_mixed}" --warning "1,warn" --critical "2,err" --normal "ok,0" --isarrayofvalidvalues -o "{setting_1_mixed}"
./check_json.pl -u https://some.rest.api/v3/settings -a "{setting_2_int}" --warning "1" --critical "2" --normal "0" --isarrayofvalidvalues -o "{setting_2_int}"

```
Result:
```
Check JSON status API OK - status: ok
Check JSON status API OK - setting_1_mixed: 0
Check JSON status API OK - setting_2_int: 0
```

### Date Example
Using divisor 3600 allows to set warning und critical in the perspective of hours.
```
./check_json.pl -u https://some.thing/event -a "{items}[0]->{modifiedAt}" --warning 24 --critical 48 -divisor 3600 --isdate -o "{items}[0]->{modifiedAt}"
```
Result:
```
Check JSON status API OK - modifiedAt: 2021-08-31T13:47:07.341Z
```

#### Example with several checks in one:
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
