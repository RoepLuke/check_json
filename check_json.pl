#!/usr/bin/env perl

use warnings;
use strict;
use HTTP::Request::Common;
use LWP::UserAgent;
use JSON;
use Monitoring::Plugin;
use Data::Dumper;
use DateTime::Format::ISO8601;

my $np = Monitoring::Plugin->new(
    usage => "Usage: %s -u|--url <http://user:pass\@host:port/url> -a|--attributes <attributes> "
    . "[ -c|--critical <thresholds / array of valid values delimited by ; as STRING> ] [ -w|--warning <thresholds / array of valid values delimited by ; as STRING> ] [ -n|--normal <array of valid values delimited by ; as STRING> ] "
    . "[ -e|--expect <value> ] "
    . "[ -p|--perfvars <fields> ] "
    . "[ -o|--outputvars <fields> ] "
    . "[ -t|--timeout <timeout> ] "
    . "[ -d|--divisor <divisor> ] "
    . "[ -m|--metadata <content> ] "
    . "[ -T|--contenttype <content-type> ] "
    . "[ --ignoressl ] "
    . "[ -x|--xauth <X-Auth-Token> ] "
    . "[ -b|--bearer <Bearer-Token> ] "
    . "[ -A|--hattrib <value> ] "
    . "[ -C|--hcon <value> ] "
    . "[ -h|--help ] ",
    version => '0.52',
    blurb   => 'Nagios plugin to check JSON attributes via http(s)',
    extra   => "\nExample: \n"
    . "check_json.pl --url http://192.168.5.10:9332/local_stats --attributes '{shares}->{dead}' "
    . "--warning :5 --critical :10 --perfvars '{shares}->{dead},{shares}->{live}' "
    . "--outputvars '{status_message}' -b <api_token>",
    url     => 'https://github.com/RoepLuke/check_json/',
    plugin  => 'check_json',
    timeout => 15,
    shortname => "Check JSON status API",
);

 # add valid command line options and build them into your usage/help documentation.
$np->add_arg(
    spec => 'url|u=s',
    help => '-u, --url http://user:pass@192.168.5.10:9332/local_stats',
    required => 1,
);

$np->add_arg(
    spec => 'attributes|a=s',
    help => '-a, --attributes {shares}->{dead},{shares}->{uptime}',
    required => 1,
);

$np->add_arg(
    spec => 'divisor|d=i',
    help => '-d, --divisor 1000000',
);

$np->add_arg(
    spec => 'warning|w=s',
    help => '-w, --warning <INTEGER:INTEGER / Array of valid values delimited by ; as STRING> . See '
    . 'http://nagiosplug.sourceforge.net/developer-guidelines.html#THRESHOLDFORMAT '
    . 'for the threshold format. ',
);

$np->add_arg(
    spec => 'critical|c=s',
    help => '-c, --critical <INTEGER:INTEGER / Array of valid values delimited by ; as STRING> . See '
    . 'http://nagiosplug.sourceforge.net/developer-guidelines.html#THRESHOLDFORMAT '
    . 'for the threshold format. ',
);

$np->add_arg(
    spec => 'normal|n=s',
    help => '-n, --normal <STRING / Array of valid values delimited by ; as STRING>'
);

$np->add_arg(
    spec => 'expect|e=s',
    help => '-e, --expect expected value to see for attribute.',
);

#$np->add_arg(
#    spec => 'expect-result-found=i',
#    help => '--expect-result-found expected return code when value given by --expect is found'
#    . 'Either UNKNOWN (-1) or OK (0) or WARNING (1) or CRITICAL (2). Default is OK'
#);

#$np->add_arg(
#    spec => 'expect-result-notfound=i',
#    help => '--expect-result_notfound expected return code when valu given by --expect is not found'
#    . 'Either UNKNOWN (-1) or OK (0) or WARNING (1) or CRITICAL (2) .Default is CRITICAL'
#);

$np->add_arg(
    spec => 'perfvars|p=s',
    help => "-p, --perfvars eg. '* or {shares}->{dead},{shares}->{live}'\n   "
    . "CSV list of fields from JSON response to include in perfdata "
);

$np->add_arg(
    spec => 'outputvars|o=s',
    help => "-o, --outputvars eg. '* or {status_message}'\n   "    
    . "CSV list of fields output in status message, same syntax as perfvars"
);

$np->add_arg(
    spec => 'metadata|m=s',
    help => "-m|--metadata \'{\"name\":\"value\"}\'\n   "
    . "RESTful request metadata in JSON format"
);

$np->add_arg(
    spec => 'contenttype|T=s',
    default => 'application/json',
    help => "-T, --contenttype application/json \n   "
    . "Content-type accepted if different from application/json ",
);

$np->add_arg(
    spec => 'ignoressl',
    help => "--ignoressl\n   Ignore bad ssl certificates",
);

$np->add_arg(
    spec => 'xauth|x=s',
    help => "-x|--xauth\n   Use X-Auth-Token in header",
);

$np->add_arg(
    spec => 'bearer|b=s',
    help => "-b|--bearer\n   Use Bearer Token authentication in header",
);

$np->add_arg(
    spec => 'isdate',
    help => "--isdate\n     attributes to check are dates.\n"
    ."The difference between the given date and now is used to determine thresholds in seconds.\n"
    ."e.g. '--warning 24: --divisor 3600' to warn when the date is more than a day old." ,
);

$np->add_arg(
    spec => 'hattrib|A=s',
    help => "-A, --header-attrib STRING \n "
    . "Additional Header attribute.",
);

$np->add_arg(
    spec => 'hcon|C=s',
    help => "-C, --header-content STRING \n "
    . "Additional Header content.",
);

## Parse @ARGV and process standard arguments (e.g. usage, help, version)
$np->getopts;
if ($np->opts->verbose) { (print Dumper ($np))};

## GET URL
my $ua = LWP::UserAgent->new;
$ua->env_proxy;
$ua->agent('check_json/0.5');
$ua->default_header('Accept' => 'application/json');
if (defined($np->opts->hattrib)) {
    $ua->default_header($np->opts->hattrib => $np->opts->hcon);
}
$ua->protocols_allowed( [ 'http', 'https'] );
$ua->parse_head(0);
$ua->timeout($np->opts->timeout);

if ($np->opts->xauth) {
    $ua->default_header('Accept' => 'application/json', 'X-Auth-Token' => $np->opts->xauth );
}

if ($np->opts->bearer) {
    $ua->default_header('Accept' => 'application/json', 'Authorization' => 'Bearer ' . $np->opts->bearer );
}

if ($np->opts->ignoressl) {
    $ua->ssl_opts(verify_hostname => 0, SSL_verify_mode => 0x00);
}

if ($np->opts->verbose) { (print Dumper ($ua))};

my $response;
if ($np->opts->metadata) {
    $response = $ua->request(GET $np->opts->url, 'Content-type' => 'application/json', 'Content' => $np->opts->metadata );
} else {
    $response = $ua->request(GET $np->opts->url);
}

#Now is the moment the response was received.
my $now = DateTime->now();

if ($response->is_success) {
    if (!($response->header("content-type") =~ $np->opts->contenttype)) {
        $np->nagios_exit(UNKNOWN,"Content type is not JSON: ".$response->header("content-type"));
    }
} else {
    $np->nagios_exit(CRITICAL, "Connection failed: ".$response->status_line);
}

## Parse JSON
my $json_response = decode_json($response->content);
if ($np->opts->verbose) { (print Dumper ($json_response))};
my @normal;
my @warning;
my @critical;
my @attributes = split(',', $np->opts->attributes);
if (!defined $np->opts->expect) {
  @normal = $np->opts->normal ? split(',',$np->opts->normal) : () ;
  @warning = $np->opts->warning ? split(',',$np->opts->warning) : () ;
  @critical = $np->opts->critical ? split(',',$np->opts->critical) : () ;
} else {
  @normal = ('');
  @warning = ('');
  @critical = ('');
}
my @divisor = $np->opts->divisor ? split(',',$np->opts->divisor) : () ;
my @isdate = $np->opts->isdate ? split(',',$np->opts->isdate) : ();
my %attributes = map { $attributes[$_] => { normal => @normal, warning => @warning, critical => @critical, divisor => ($divisor[$_] or 0), isdate => ($isdate[$_] or 0) } } 0..$#attributes;

if ($np->opts->verbose) { (print Dumper (%attributes))};

my %check_value;
my $check_value;
my $result = -1;
my $resultTmp;

##Result List
# -1 = UNKNOWN
# 0 = OK
# 1 = WARNING
# 2 = CRITICAL

foreach my $attribute (sort keys %attributes){
    my $check_value;
    my $check_value_str = '$check_value = $json_response->'.$attribute;
    
    if ($np->opts->verbose) { (print Dumper ($check_value_str))};
    eval $check_value_str;

    if (!defined $check_value) {
        $np->nagios_exit(UNKNOWN, "No value received");
    }
    
    # The difference between the given date and now is used as new check_value in seconds
    if ($attributes{$attribute}{'isdate'}){
        my $date;
        eval {
            $date = DateTime::Format::ISO8601->parse_datetime($check_value);
        };
        if ( $@ ) { $np->nagios_exit(UNKNOWN, "Date is not valid.");}

        $check_value = $now->subtract_datetime_absolute($date)->seconds;
    }

    if ($attributes{$attribute}{'divisor'}) {
        $check_value = $check_value/$attributes{$attribute}{'divisor'};
    }

    if (defined $np->opts->expect) {
        if ($np->opts->expect ne $check_value) {
#            $np->nagios_exit(CRITICAL, "Expected value (" . $np->opts->expect . ") not found. Actual: " . $check_value);
#            if (defined $np->opts->expect-result-notfound && $np->opts->expect-result-notfound lt 3 && $np->opts->expect-result-notfound gt -2) {
#                $resultTmp = $np->opts->expect-result-notfound;
#            } else {
                $resultTmp = 2;
#            }
        } else {
#            $np->nagios_exit(OK, '');
#            if (defined $np->opts->expect-result-found && $np->opts->expect-result-found lt 3 && $np->opts->expect-result-found gt -2) {
#                $resultTmp = $np->opts->expect-result-found;
#            } else {
                $resultTmp = 0;
#            }
        }
    } else {
        if ( $check_value eq "true" or $check_value eq "false" ) {
            if ( $check_value eq "true") {
                $resultTmp = 0;
                if ($attributes{$attribute}{'critical'} eq 1 or $attributes{$attribute}{'critical'} eq "true") {
                    $resultTmp = 2;
                } else {
                    if ($attributes{$attribute}{'warning'} eq 1 or $attributes{$attribute}{'warning'} eq "true") {
                        $resultTmp = 1;
                    }
                }
            }
            if ( $check_value eq "false") {
                $resultTmp = 0;
                if ($attributes{$attribute}{'critical'} eq 0 or $attributes{$attribute}{'critical'} eq "false") {
                    $resultTmp = 2;
                } else {
                    if ($attributes{$attribute}{'warning'} eq 0 or $attributes{$attribute}{'warning'} eq "false") {
                        $resultTmp = 1;
                    }
                }
            }
        } else {
            if ( $attributes{$attribute}{'critical'} ne '' ) {
                if ( $attributes{$attribute}{'critical'} =~ m/;/ ) {
                    if ($np->opts->verbose) { (print "Interpreted critical as array\n") };
                    my @validvalues = split(';', $attributes{$attribute}{'critical'});
                    foreach my $value ( @validvalues ) {
                        if ($np->opts->verbose) { (print "$check_value = $value ?") };
                        if ( $check_value eq $value ) {
                            $resultTmp = 2;
                            if ($np->opts->verbose) { (print " Yes!\n") };
                        } else {
                            if ($np->opts->verbose) { (print " No!\n") };
                        }
                    }
                } else {
                    if ($np->opts->verbose) { (print "Interpreted critical as string\n") };
                    if ($np->opts->verbose) { (print "$check_value = $attributes{$attribute}{'critical'} ?") };
                    if ($attributes{$attribute}{'critical'} eq $check_value) {
                        $resultTmp = 2;
                        if ($np->opts->verbose) { (print " Yes!\n") };
                    } else {
                        if ($np->opts->verbose) { (print " No!\n") };
                    }
                }
            }
            if ( $attributes{$attribute}{'warning'} ne '' ) {
                if ( $attributes{$attribute}{'warning'} =~ m/;/ ) {
                    if ($np->opts->verbose) { (print "Interpreted warning as array\n") };
                    my @validvalues = split(';', $attributes{$attribute}{'warning'});
                    foreach my $value ( @validvalues ) {
                        if ($np->opts->verbose) { (print "$check_value = $value ?") };
                        if ( $check_value eq $value ) {
                            $resultTmp = 1;
                            if ($np->opts->verbose) { (print " Yes!\n") };
                        } else {
                            if ($np->opts->verbose) { (print " No!\n") };
                        }
                    }
                } else {
                    if ($np->opts->verbose) { (print "Interpreted warning as string\n") };
                    if ($np->opts->verbose) { (print "$check_value = $attributes{$attribute}{'warning'} ?") };
                    if ($attributes{$attribute}{'warning'} eq $check_value) {
                        $resultTmp = 1;
                        if ($np->opts->verbose) { (print " Yes!\n") };
                    } else {
                        if ($np->opts->verbose) { (print " No!\n") };
                    }
                }
            }
            if ( $attributes{$attribute}{'normal'} ne '' ) {
                if ( $attributes{$attribute}{'normal'} =~ m/;/ ) {
                    if ($np->opts->verbose) { (print "Interpreted normal as array\n") };
                    my @validvalues = split(';', $attributes{$attribute}{'normal'});
                    foreach my $value ( @validvalues ) {
                        if ($np->opts->verbose) { (print "$check_value = $value ?") };
                        if ($check_value eq $value) {
                            $resultTmp = 0;
                            if ($np->opts->verbose) { (print " Yes!\n") };
                        } else {
                            if ($np->opts->verbose) { (print " No!\n") };
                        }
                    }
                } else {
                    if ($np->opts->verbose) { (print "Interpreted normal as string\n") };
                    if ($np->opts->verbose) { (print "$check_value = $attributes{$attribute}{'normal'} ?") };
                    if ($attributes{$attribute}{'normal'} eq $check_value) {
                        $resultTmp = 0;
                        if ($np->opts->verbose) { (print " Yes!\n") };
                    } else {
                        if ($np->opts->verbose) { (print " No!\n") };
                    }
                }
            }

            if ($np->opts->verbose) { (print "ResultTmp is $resultTmp\n") };
            if ($resultTmp == -1 && $attributes{$attribute}{'warning'} ne '' && $attributes{$attribute}{'critical'} ne '') {
                $resultTmp = $np->check_threshold(
                    check => $check_value,
                    warning => $attributes{$attribute}{'warning'},
                    critical => $attributes{$attribute}{'critical'}
                );
            }
        }
    }
    $result = $resultTmp if $result < $resultTmp;
    $attributes{$attribute}{'check_value'}=$check_value;
}

my @statusmsg;


# routine to add perfdata from JSON response based on a loop of keys given in perfvals (csv)
if ($np->opts->perfvars) {
    foreach my $key ($np->opts->perfvars eq '*' ? map { "{$_}"} sort keys %$json_response : split(',', $np->opts->perfvars)) {
        # use last element of key as label
        my $label = (split('->', $key))[-1];
        # make label ascii compatible
        $label =~ s/[^a-zA-Z0-9_-]//g  ;
        my $perf_value;
        my $perf_value_str = '$perf_value = $json_response->'.$key;
        eval $perf_value_str;
        if ($np->opts->verbose) { print Dumper ("JSON key: ".$label.", JSON val: " . $perf_value) };
        if ( defined($perf_value) ) {
            # add threshold if attribute option matches key
            if ($attributes{$key}) {
                push(@statusmsg, "$label: $attributes{$key}{'check_value'}");
                $np->add_perfdata(
                    label => lc $label,
                    value => $attributes{$key}{'check_value'},
                    threshold => $np->set_thresholds( warning => $attributes{$key}{'warning'}, critical => $attributes{$key}{'critical'}),
                );
            } else {
                push(@statusmsg, "$label: $perf_value");
                $np->add_perfdata(
                    label => lc $label,
                    value => $perf_value,
                );            
            }
        }
    }
}

# output some vars in message
if ($np->opts->outputvars) {
    foreach my $key ($np->opts->outputvars eq '*' ? map { "{$_}"} sort keys %$json_response : split(',', $np->opts->outputvars)) {
        # use last element of key as label
        my $label = (split('->', $key))[-1];
        # make label ascii compatible
        $label =~ s/[^a-zA-Z0-9_-]//g;
        my $output_value;
        my $output_value_str = '$output_value = $json_response->'.$key;
        eval $output_value_str;
        push(@statusmsg, "$label: $output_value");
    }
}

if ($np->opts->verbose) { 
    print "return code is $result\n";
    print "Status message is @statusmsg\n";

}

$np->nagios_exit(
    return_code => $result,
    message     => join(', ', @statusmsg),
);
