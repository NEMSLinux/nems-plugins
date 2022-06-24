#!/usr/bin/perl -w
#
# Check temperature of 1Wire device
# Requires use of Fuse and owfs
#
#

use strict;
use Getopt::Std;
use OW;

my $owserver = "127.0.0.1:3001";

use vars qw($opt_v $opt_l $opt_h $opt_H $opt_L $opt_w);
my(%ERRORS) = ( OK=>0, WARNING=>1, CRITICAL=>2, UNKNOWN=>3, WARN=>1, CRIT=>2 );
my($message, $status);
my (@ignore);

sub print_usage () {
	print "Usage: \n\t1wire_temp [-v] [-h] -l low_temp_warn -L low_temp_crit -w high_temp_warn -H high_temp_crit\n\n";
}

sub print_help () {
	print <<HELP;

		1wire_temp version 0.2
		
		Copyright 2006 Matt Gresko
		mgresko\@mattgresko.com
		www.mattgresko.com
		
		
		
HELP
	
	print_usage();
}

# return true if parameter is not in ignore list
sub valid($) {
	my($v) = $_[0];
	$v = lc $v;
	foreach ( @ignore ) { return 0 if((lc $_) eq $v); }
	return 1;
}

sub check_temp {
	my($l) = shift;
	my($L) = shift;
	my($w) = shift;
	my($H) = shift;


	unless(OW::init($owserver)) {
	    $status = $ERRORS{CRIT};
	    $message = "OWServer not running at $owserver\n";
	    exit $status;
	}

	my $handle = OW::get('10.D7C3C8000800/temperature');

#	open TEMP,"</mnt/1wire_temp/10.D7C3C8000800/temperature" 
#		or return($ERRORS{CRITICAL});
		
#	while( $handle = <TEMP> ) {
	    ## Remove white space from begninning and end of input
	    $handle =~ s/^\s*(.*?)\s*$/$1/;
	    
	    ## Check if input is an integer or decimal
		unless (($handle =~ /^-?(?:\d+(?:\.\d*)?|\.\d+)$/) || ($handle =~ /^[+-]?\d+$/)) 
		{
			print "Not an integer or a decimal\n";
			return($ERRORS{CRITICAL});
		}
		## Convert from celsius to farenheit 
		my $farenheit = ($handle * 1.8) + 32;
		## Round temperature to 2 decimal places
		$farenheit = sprintf("%.2f", $farenheit);
		
		if(($farenheit <= $l) && ($farenheit > $L)) {
			$status = $ERRORS{WARN};
		}
		if($farenheit <= $L) {
			$status = $ERRORS{CRIT};
		}
		if(($farenheit >= $w) && ($farenheit < $H)) {
			$status = $ERRORS{WARN};
		}
		if($farenheit >= $H) {
			$status = $ERRORS{CRIT};
		}		
	    	$message = "$farenheit F";
#	}
#	close TEMP;
}

$ENV{'BASH_ENV'}=''; 
$ENV{'ENV'}='';

our($opt_l, $opt_L, $opt_w, $opt_H, $opt_v, $opt_h);

getopts("l:L:w:H:v:h");

my @vars = ($opt_l, $opt_L, $opt_w, $opt_H);

if ($opt_h) {print_help(); exit $ERRORS{'OK'};}

# Check for necessary flags
foreach ( @vars ) {
	unless($_) {
		print_help();
		exit $ERRORS{WARNING};
	}
}

$status = $ERRORS{OK}; $message = '';

if(($opt_l <= 0) && ($opt_L <= 0)) {
	print "Low temperature must be above 0\n\n";	
	print_help(); exit $ERRORS{'WARN'};
}
if(($opt_w || $opt_H) < ($opt_l || $opt_L)) {
	print "High temperature must be above low temperature\n\n";
	print_help(); exit $ERRORS{'WARN'};
}

## Check if 1wire device is connected
check_temp($opt_l,$opt_L,$opt_w,$opt_H); #if( -d "/mnt/1wire_temp/bus.0/" );

if( $message ) {
	if( $status == $ERRORS{OK} ) {
		print "OK: ";
	} elsif( $status == $ERRORS{WARNING} ) {
		print "WARNING: ";
	} elsif( $status == $ERRORS{CRITICAL} ) {
		print "CRITICAL: ";
	}
	print "$message\n";
} else {
	print "\nNo 1wire device found.\n\n\a";
	exit $ERRORS{CRITICAL};
}
exit $status;
