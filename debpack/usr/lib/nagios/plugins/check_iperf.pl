#!/usr/bin/perl -w
## $Id: check_iperf.pl 232 2006-10-01 15:23:55Z touche $
##	julien.touche@touche.fr.st
##
## nagios script to check speed between network links
##
## windows or unix, with iperf installed and an iperf service on target

use strict;

$ENV{'PATH'}='';
$ENV{'BASH_ENV'}='';
$ENV{'ENV'}='';

my ($target,$exit);
#my $iperf = "c:\\temp\\iperf.exe";
my $iperf = "/usr/local/bin/iperf";

if ($#ARGV+1 !=3) {
	usage();
	exit;
} elsif (! -f "$iperf") {
	print "didn't find iperf here '$iperf'.\n";
	exit;
} else {
	$target = $ARGV[0];
}


our ($mtu,$connect_ok,$speed,$unit);
$connect_ok = 0;
$speed = "UNKNOWN";

my ($maxwarn,$maxcrit,$minwarn,$mincrit);
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


print "DEBUG: $iperf -c $target -m\n";
open(OUT, "$iperf -c $target -m |");
while (<OUT>) {
	chomp;
	#print "DEBUG: '$_'\n";
	if (m/TCP window size: ([0-9\.].+) (\w)/) {
		$mtu = "$1 $2";
	} elsif (m/connected with/) {
		$connect_ok = 1;
	} elsif (m/^\[.*\]  [0-9-\.].+ sec.*[0-9\.] .Bytes\s*([0-9].*) (.*)$/) {
		print "DEBUG: '$_' ; '$1', '$2' \n";
		$speed = $1;
		$unit = $2;
	}
}

if ($connect_ok == 0) {
	print "NOK: iperf didn't connect to '$target'.\n"; $exit = 2;
} elsif ($speed<$mincrit) {
	print "Critical: iperf speed of '$target': $speed ($unit) < $mincrit.\n";$exit=2;
} elsif (defined($maxcrit) && $speed > $maxcrit) {
	print "Critical: iperf speed of '$target': $speed ($unit) > $maxcrit.\n";$exit=2;
} elsif ($speed < $minwarn) {
	print "Warning: iperf speed of '$target': $speed ($unit) < $minwarn.\n";$exit=1;
} elsif (defined($maxwarn) && $speed > $maxwarn) {
	print "Warning: iperf speed of '$target': $speed ($unit) > $maxwarn.\n";$exit=2;
} else {
	print "OK: iperf returns $speed $unit (wsize $mtu).\n"; $exit = 0;
}



sub usage {
	print <<EOL
 $0 <target host> "Critical speed" "Warning speed": 
 	this plugin returns iperf usage

 examples:
	$0 <host> 10 15: critical if speed under 10 units
	$0 <host> 10 15:50: warning if speed out of 15:50 units
	$0 <host> 10:100 15:90
	$0 <host> 10:40 15:90
	
EOL

}


exit $exit;
