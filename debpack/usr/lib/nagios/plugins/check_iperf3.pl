#!/usr/bin/perl -W
##	Original version by julien.touche@touche.fr.st
##  Customized by Marcelo.Espinosa@gmail.com
##
## nagios script to check speed between network links
##
## windows or unix, with iperf3 installed and an iperf3 service on target
##
##  check_iperf3.pl, Version 0.1
##
##



=pod

This script was modified from the original version made by Julien Touche 
with the intention to support iperf3.

check_iperf3.pl allows you to test both, TCP and UDP protocols, also, 
PERFORMANCE DATA is returned back to Nagios.

Keep in mind that iper3 is not compatible with iperf2, so
this script will run succesfully with an <iperf3_target_server> only.

=item Install

 $ sudo install --mode=755 check_iperf3.pl /usr/local/bin
 $ sudo cpan -i JSON
 
=item NRPE setup

in /etc/nagios/nrpe_local.cfg add the following lines (run check_iperf3.pl
without parameters for usage instructions):

 # get link_max_capacity, critical under 50, warning under 60
 command[chk_iperf3_tcp]=/usr/local/bin/check_iperf3.pl <target_iperf3_server> 50 60
 
 # udp 300Mbps/sec test 
 command[chk_iperf3_udp]=/usr/local/bin/check_iperf3.pl <target_iperf3_server> 150 200 300M
 ...
 # udp 3Mbps/sec wifi test 
 command[chk_iperf3_udp_wifi_6Mbps]=/usr/local/bin/check_iperf3.pl <target_iperf3_server> 4:8 5:7 6M

=item NAGIOS server

In Nagios Server you must create a new check_nrpe command wich will call
the machine running nrpe_server + check_iperf3.pl(wich wraps iperf3 client).

By default <check_iperf3.pl> run a 30 seconds test, so it's necessary to
define a custom "timeout". (standard check_nrpe defaults to 10 seconds).

 define command {
   command_name   check_nrpe_iperf
   command_line   $USER1$/check_nrpe -H $HOSTADDRESS$ -t 60 -c $ARG1$
 }
 
=item TCP sample output

	$ check_iperf3.pl 10.0.1.10 5 10   
	OK: iperf returns 11.01MB |Bandwidth=11.01MB
	INFO: 
	************************************************************
	  Iperf Version         : iperf 3.0.11
	  Remote Host:Port      : 10.0.1.10:5201
	  Protocol              : TCP
	  TCP MTU               : 1340
	  Streams               : 1
	  Test duration (sec)   : 30
	  Speed (bytes/sec)     : 11.01 MB/sec
	  Speed (bits/sec)      : 88.11 Mb/sec
	  Block Size            : 131072
	  Bytes transmitted     : 330415860
	************************************************************
	DEBUG CMD: $ /usr/bin/iperf3 -J -c 10.0.1.10  -t 30 


=item UDP sample output

	$ check_iperf3.pl 10.0.1.10 5 10 120M
	OK: iperf returns 14.71MB |Bandwidth=14.71MB;;;; Jitter=60.0712ms;;;; Lost_packets_ratio=98.87%;;;;
	INFO: 
	************************************************************
	  Iperf Version         : iperf 3.0.11
	  Remote Host:Port      : 10.0.1.10:5201
	  Protocol              : UDP
	  Streams               : 1
	  Test duration (sec)   : 5
	  Speed (bytes/sec)     : 14.71 MB/sec
	  Speed (bits/sec)      : 117.65 Mb/sec
	  Block Size            : 8192
	  Packets transmitted   : 8795
	  Bytes transmitted     : 73531392
	  Jitter (ms)           : 60.0712
	  Lost Packets          : 8696
	  Lost/Total Ratio (%)  : 8696/8795 (98.87)
	************************************************************
	DEBUG CMD: $ /usr/bin/iperf3 -J -c 10.0.1.10 -u -b 120M -t 5 

	Wow!, see the packet lost ratio!
	
=cut 

use strict;
use Switch;
use JSON qw(from_json);
use POSIX qw(setlocale LC_NUMERIC);
use locale;

setlocale LC_NUMERIC, "es_CL.UTF-8";

my $debug = 1;

my ($target,$exit);
my ($proto,$proto_opts,$maxwarn,$maxcrit,$minwarn,$mincrit,$bandwidth, $bw_arg);
my ($bytes, $mtu, $jitter_ms, $lost_packets , $packets);
my ($duration, $perfdata, $default_scale);
my ($connect_ok, $json, $cmd_options, $text, $time, $alert,$lost_percent);
my ($bps, $Bps, $bps_out, $fmt_bps, $Bps_out, $fmt_Bps, $fmt);

my $iperf = "/usr/bin/iperf3";

if (($#ARGV+1 < 3) || ($#ARGV+1 > 4)) {
	usage();
	exit;
} elsif (! -f "$iperf") {
	print "didn't find iperf here '$iperf'.\n";
	exit;
} else {
	$target = $ARGV[0];
}
$proto = ($#ARGV+1 == 3) ? "tcp" : "udp";
$proto_opts = "";
$default_scale = "M";

if ($proto eq "udp" ) {
	$bw_arg = $ARGV[3];
	if ($bw_arg =~ m/^(\d+)([KMG])(b?)$/) {  # allowed [K|Kb|M|Mb|G|Gb]
			$default_scale = "$2";
			$bandwidth = "$1$2";
	} else {
		$alert  = sprintf("%s", "NOK: check_iperf3.pl: invalid bandwidth '$bw_arg'.\n");
		$alert .= sprintf("%s", "Usage: <number>[KMG]b\n");
		$alert .= sprintf("%s", "       'b' is optional because target bandwidth is in 'bits/sec'\n"); 
		print $alert;
		$exit = 2;
		exit $exit;
	}
	$proto_opts = "-u -b $bandwidth";	
}

$mincrit = $ARGV[1];
if ($mincrit =~ m/([0-9].+):([0-9].+)/) {
	$mincrit = $1;
	$maxcrit = $2;
}
$minwarn = $ARGV[2];
if ($minwarn =~ m/([0-9].+):([0-9].+)/) {
	$minwarn = $1;
	$maxwarn = $2;
}

$time = 30;  # in seconds
$cmd_options = "-J -c $target $proto_opts -t $time ";
$text='';

open (my $fh, "-|", "$iperf $cmd_options");
while (<$fh>) {
	chomp;
	$text .= $_;
}
close $fh;

$json = from_json($text);

$connect_ok = (defined $json->{error}) ? 0 : 1;
$connect_ok = (defined $json->{start}{connected}[0]{remote_host}) ? 1 : 0;
if ($connect_ok == 0) {
	print "NOK: iperf didn't connect to '$target'.\n"; 
	print "$json->{error} \n" if ($json->{error});
	$exit = 2;
	exit $exit;
}

my %scale = (
	"K" => { 'factor' =>1000, 'format' => "%.2f" },
	"M" => { 'factor' =>1000000, 'format' => "%.2f" },
	"G" => { 'factor' =>1000000000, 'format' => "%.2f" }
);

# extract relevant data from JSON 
# Bps: Bytes per Second  |  bps=bits per second !!
switch ($proto) {
	case "tcp" {
		$bytes = (defined $json->{end}{sum_sent}{bytes} ) ? $json->{end}{sum_sent}{bytes} : -1;
		$bps = (defined $json->{end}{sum_sent}{bits_per_second}) ? $json->{end}{sum_sent}{bits_per_second} : -1;
		$mtu = (defined $json->{start}{tcp_mss_default}) ? $json->{start}{tcp_mss_default} : -1;
		$duration = (defined $json->{end}{sum_sent}{seconds}) ? $json->{end}{sum_sent}{seconds} : -1;
	}
	case "udp" {
		$bytes = (defined $json->{end}{sum}{bytes}) ? $json->{end}{sum}{bytes} : -1;
		$packets = (defined $json->{end}{sum}{packets}) ? $json->{end}{sum}{packets} : -1;
		$bps = (defined $json->{end}{sum}{bits_per_second}) ? $json->{end}{sum}{bits_per_second} : -1;
		$jitter_ms = (defined $json->{end}{sum}{jitter_ms}) ? $json->{end}{sum}{jitter_ms} : -1;
		$lost_packets = (defined $json->{end}{sum}{lost_packets}) ? $json->{end}{sum}{lost_packets} : -1;
		$lost_percent = (defined $json->{end}{sum}{lost_percent}) ? $json->{end}{sum}{lost_percent} : -1;
		$duration = (defined $json->{end}{sum}{seconds}) ? $json->{end}{sum}{seconds} : -1;	
	}
}

$Bps = ( $bytes / $duration ) / $scale{"$default_scale"}->{'factor'}; 
$bps = $bps / $scale{"$default_scale"}->{'factor'}; 

$fmt_Bps = ($Bps > 1) ? $scale{$default_scale}->{'format'} : "%.4f";
$fmt_bps = ($bps > 1) ? $scale{$default_scale}->{'format'} : "%.4f";

$Bps_out = sprintf($fmt_Bps, $Bps);
$bps_out = sprintf($fmt_bps, $bps);

my $extra = "INFO: \n";
$extra .= sprintf("%s\n","*"x60);
$extra .= sprintf("  %-22s: %s\n","Iperf Version", $json->{start}{version});
$extra .= sprintf("  %-22s: %s:%s\n","Remote Host:Port", $json->{start}{connected}[0]{remote_host},$json->{start}{connected}[0]{remote_port});
$extra .= sprintf("  %-22s: %s\n","Protocol", $json->{start}{test_start}{protocol});
$extra .= sprintf("  %-22s: %s\n","TCP MTU", $mtu) if ($proto eq "tcp");
$extra .= sprintf("  %-22s: %s\n","Streams", $json->{start}{test_start}{num_streams});
$extra .= sprintf("  %-22s: %s\n","Test duration (sec)", $json->{start}{test_start}{duration});
$extra .= sprintf("  %-22s: %s %s%s\n","Speed (bytes/sec)", $Bps_out, $default_scale, "B/sec");
$extra .= sprintf("  %-22s: %s %s%s\n","Speed (bits/sec)", $bps_out, $default_scale, "b/sec");
$extra .= sprintf("  %-22s: %s\n","Block Size", $json->{start}{test_start}{blksize});
$extra .= sprintf("  %-22s: %s\n","Packets transmitted", $packets)  if ($proto eq "udp");
$extra .= sprintf("  %-22s: %s\n","Bytes transmitted", $bytes);
$extra .= sprintf("  %-22s: %s\n","Jitter (ms)", $jitter_ms) if ($proto eq "udp");
$extra .= sprintf("  %-22s: %s\n","Lost Packets", $lost_packets) if ($proto eq "udp");
$extra .= sprintf("  %-22s: %s/%s (%.2f)\n","Lost/Total Ratio (%)", $lost_packets, $packets, $lost_percent) if ($proto eq "udp");
$extra .= sprintf("%s\n","*"x60);
$extra .= sprintf("DEBUG CMD: \$ %s %s\n", $iperf, $cmd_options) if $debug; 


# Throw output to NAGIOS
#   Perfdata expects the output in 'B' - bytes (also KB, MB, TB, GB).
#   for consistency all data is returned in 'B'
if ($proto eq "tcp") {
	$perfdata = "Bandwidth=${Bps_out}${default_scale}B";
}
if ($proto eq "udp") {
	$lost_percent = sprintf("%.2f", $lost_percent);
	$perfdata = "Bandwidth=${Bps_out}${default_scale}B;;;; Jitter=${jitter_ms}ms;;;; Lost_packets_ratio=$lost_percent%;;;;";
}

if ($Bps<$mincrit) {
	print "Critical: iperf speed of '$target' is $Bps_out and [mincrit:$mincrit]|$perfdata\n";
	print $extra;
	$exit=2;
} elsif (defined($maxcrit) && $Bps > $maxcrit) {
	print "Critical: iperf speed of '$target' is $Bps_out and [maxcrit:$maxcrit]|$perfdata\n";
	print $extra;
	$exit=2;
} elsif ($Bps < $minwarn) {
	print "Warning: iperf speed of '$target' is $Bps_out and [minwarn:$minwarn]|$perfdata\n";
	print $extra;
	$exit=1;
} elsif (defined($maxwarn) && $Bps > $maxwarn) {
	print "Warning: iperf speed of '$target' is $Bps_out and [maxwarn: $maxwarn]|$perfdata\n";
	print $extra;
	$exit=2;
} else {
	print "OK: iperf returns ${Bps_out}${default_scale}B |$perfdata\n"; 
	print $extra;
	$exit = 0;
}


sub usage {
	print <<EOL

  This plugin returns the output of iperf3, wich is an active
  measurements of the maximum achievable bandwidth on IP networks. 
  
  TCP usage (tell me the max bandwidth available):
  ------------------------------------------------
  
    \$ check_iperf3.pl <target_host> <Crit> <Warn> 
    
    Where:
      <target_host> Target host
      <Crit>        Critical speed unit, range allowed in the form x:y
      <Warn>        Warning speed unit, range allowed in the form x:y
		
  UDP usage (test at an specific bandwidth target):
  -------------------------------------------------
  
    \$ check_iperf3.pl <target_host> <Crit> <Warn> <Bandwidth>
    
    Where:
      <target_host> Target host
      <Crit>        Critical speed unit, range allowed in the form x:y
      <Warn>        Warning speed unit, range allowed in the form x:y
      <Bandwidth>   <target_bandwidth>[KMG]       (test is made in bits/sec)
		 

  examples:
	check_iperf3.pl <host> 10 15         ; critical if speed under 10 units
	check_iperf3.pl <host> 10 15:50      ; warning if speed out of 15:50 units
	check_iperf3.pl <host> 10:100 15:90
	check_iperf3.pl <host> 20 35 40M     ; UDP test at 40 Mbits/sec
	check_iperf3.pl <host> 20 35 1G      ; UDP test at 1 Gbit/sec
	
EOL

}


exit $exit;


