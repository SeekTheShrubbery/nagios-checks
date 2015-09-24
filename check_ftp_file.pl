#!/usr/bin/perl

use Net::FTP;
use strict;
use warnings;
use Getopt::Long;

# Constannt
my $STATE_OK = 0;
my $STATE_WARNING = 1; 
my $STATE_CRITICAL = 2;
my $STATE_UNKNOWN=3;
my $PROGNAME = "check_ftp_file.pl";
my $TMPPATH = "/dev/shm";
my $TIMEOUT = 5;
my $TIMESHIFT = 60*10;

# Variables
my ($opt_S,$opt_user,$opt_password,$opt_f,$opt_p,$opt_t,$opt_a,$opt_h);
my ($SERVER,$USER,$PASSWORD,$FILE,$PATH);
my ($mdtm_time, $current_time, $diff_time, $ftp, $output, $longoutput);
my $exit_code = 0;
my (@line, @msg);

Getopt::Long::Configure('bundling');
GetOptions(
        "H=s"   => \$opt_S, "Hostname"         => \$opt_S,
        "u=s"   => \$opt_user, "ftpuser"            => \$opt_user,
        "p=s" => \$opt_password, "ftppassword"       => \$opt_password,
        "f=s" => \$opt_f, "filename"        => \$opt_f,
        "e=s" => \$opt_p, "pathonftp"            => \$opt_p,
        "t=i" => \$opt_t, "timeout=i"       => \$opt_t,
        "a=i" => \$opt_a, "fileage=i"      => \$opt_a,
		"h"   => \$opt_h, "Help"         => \$opt_h);

sub print_usage () {
        print "Usage:\n";
        print "  $PROGNAME -H <hostname> -u <ftpuser> -p <ftppassword> -f <filename> -e <pathonftp> [-t <timeout>] [-a <fileage>]\n";
        print "  $PROGNAME [-h | --help]\n";
        print "\n\nOptions:\n";
        print "  -H\n";
        print "     Host name or IP Address\n";
        print "  -u\n";
        print "     FTP Username\n";
        print "  -p\n";
        print "     FTP Password\n";
        print "  -f\n";
        print "     Filename on FTP\n";
        print "  -e\n";
        print "     Path of file on FTP\n";
        print "  -t\n";
        print "     Timeout \(Default: 5 seconds\))\n";
        print "  -a\n";
        print "     Age of file on FTP \(Default: 1h\)\n";
}
		
if ($opt_a) {
        $TIMEOUT=$opt_t;
}

if ($opt_a) {
        $TIMESHIFT=$opt_a;
}

if ($opt_h) {
        print_usage();
        exit $STATE_UNKNOWN;
}

# Main
chdir($TMPPATH);
$ftp = Net::FTP->new($opt_S, Debug => 0, Timeout => $TIMEOUT)
	or die "Cannot connect to $SERVER: $@";
$ftp->login($opt_user,$opt_password)
	or die "Cannot login ", $ftp->message;
$ftp->cwd($opt_p)
	or die "Cannot change working directory ", $ftp->message;
$current_time = time();
$mdtm_time = $ftp->mdtm ($opt_f)  
	or die "Cannot get modification date of file/or file doesn't exist", $ftp->message;
$diff_time = $current_time-$mdtm_time;
if ($diff_time>$TIMESHIFT){
	$output .= "Remote file exceeds defined time difference by $diff_time seconds ";
	$exit_code = $STATE_WARNING;
}
$ftp->binary()
	or die "failed to change to binary mode", $ftp->message;
$ftp->get($opt_f)
	or die "get failed ", $ftp->message;
$ftp->quit;

# Open File
open(my $fh, "<", $opt_f) 
	or die "cannot open < $opt_f: $!";
# Loop through lines
while (my $line = <$fh>) {
	chomp($line);
	my @msg = split /;/ , $line;
	SWITCH: {
		if ($msg[2] == "0") {
			#OK
			$output .= "OK: $msg[1] - $msg[4] ";
			$longoutput .= "OK: $msg[1] - $msg[4]\n";
			if (!$exit_code) {$exit_code= $STATE_OK};
			last SWITCH;
		};	
		if ($msg[2] == "1") {
			#Warning
			$output .= "WARNING: $msg[1] - $msg[4] ";
			$longoutput .= "WARNING: $msg[1] - $msg[4]\n";
			if ($exit_code<$STATE_WARNING) { $exit_code = $STATE_WARNING};
			last SWITCH;
		};	
		if ($msg[2] == "2") {
			#Critical
			$output .= "CRITICAL: $msg[1] - $msg[4] ";
			$longoutput .= "CRITICAL: $msg[1] - $msg[4]\n";
			if ($exit_code<$STATE_CRITICAL) { $exit_code = $STATE_CRITICAL};
			last SWITCH;
		};	
		if ($msg[2] == "3") {
			#Unknown
			$output .= "UNKNOWN: $msg[1] - $msg[4] ";
			$longoutput .= "UNKNOWN: $msg[1] - $msg[4]\n";
			if ($exit_code<$STATE_UNKNOWN) { $exit_code = $STATE_UNKNOWN};
			last SWITCH;
		};	
	#Default
	$output .= "UNKNOWN Status Code ";
	$longoutput .="UNKNOWN Status Code\n";
	if ($exit_code<$STATE_UNKNOWN) { $exit_code = $STATE_UNKNOWN};
	}
}
close  $fh;

# Output
print "$output\n";
print $longoutput;
exit $exit_code;
