#!/usr/bin/perl

use Net::FTP;
use strict;
use warnings;
use Getopt::Long;
use FindBin;
use lib "$FindBin::Bin/../perl/lib";
use Monitoring::Plugin;
use File::Basename;

# Vars
my ($code,$message);
my ($SERVER,$USER,$PASSWORD,$FILE,$PATH);
my ($mdtm_time, $current_time, $diff_time, $ftp, $t_shift);

my $exit_code = 0;
my (@line, @msg);

my $t_out = 15;
my $VERSION = 1;
my $PROGNAME = basename($0);
my $TMPPATH = "c:/Daten";

# Teststring ./test.pl -H ksl-vw2k530.gsdnet.ch -u ew.luks054.ksl -p ERcd45.e -f KSL-VLNX082.txt -e /ew.luks054.ksl/Mirth3

my $p = Monitoring::Plugin->new( 
	usage => "Usage: %s -H <hostname> -u <ftpuser> -p <ftppassword> -f <filename> -e <pathonftp> [-t <timeout>] [-a <fileage>]",
	version => $VERSION,
	blurb => "Checks Mirth File output on FTP Server",
	extra => "
	    Options:
        -H
			Host name or IP Address
        -u
          FTP Username
        -p
          FTP Password
        -f
          Filename on FTP
        -e
          Path of file on FTP
        -t
          Timeout (Default: 5 seconds)
        -a
          Age of file on FTP ()Default: 1h\)
	",
	);

$p->add_arg(
    spec => 'H|hostname=s',
    help =>	
	qq{-H, --hostname=STRING
		Hostname},
);

$p->add_arg(
    spec => 'u|ftpuser=s',
    help =>	
	qq{-u, --ftpuser=STRING
		FTP User},
);

$p->add_arg(
    spec => 'p|ftppassword=s',
    help =>	
	qq{-p, --ftppassword=STRING
		FTP Password},
);

$p->add_arg(
    spec => 'f|file=s',
    help =>	
	qq{-f, --file=STRING
		Hostname},
);

$p->add_arg(
    spec => 'e|path=s',
    help =>	
	qq{-e, --path=STRING
		Path on FTP},
);

$p->add_arg(
    spec => 't|timeout=i',
    help =>	
	qq{-t, --timeout=STRING
		Timeout},
);

$p->add_arg(
    spec => 'a|fileage=i',
    help =>	
	qq{-a, --fileage [INTEGER]
		Fileage},
);

# Parse arguments and process standard ones (e.g. usage, help, version)
$p->getopts;

# perform sanity checking on command line options
if (defined $p->opts->t) {
    $t_out = $p->opts->timeout;
}

if (!defined $p->opts->a) {
	$t_shift = 60*10;
}
		
# Main
chdir($TMPPATH);
$ftp = Net::FTP->new($p->opts->H, Debug => 0, Timeout => $t_out)
	or die "Cannot connect to $SERVER: $@";
$ftp->login($p->opts->u,$p->opts->p)
	or die "Cannot login ", $ftp->message;
$ftp->cwd($p->opts->e)
	or die "Cannot change working directory ", $ftp->message;
$current_time = time();
$mdtm_time = $ftp->mdtm ($p->opts->f)  
	or die "Cannot get modification date of file/or file doesn't exist", $ftp->message;
$diff_time = $current_time-$mdtm_time;
if ($diff_time>$t_shift){
	$p->add_message(WARNING, "Remote file off by $diff_time seconds");
}

$ftp->binary()
	or die "failed to change to binary mode", $ftp->message;
$ftp->get($p->opts->f)
	or die "get failed ", $ftp->message;
$ftp->quit;

# Open File
open(my $fh, "<", $p->opts->f) 
	or die "cannot open < $p->opts->f: $!";
# Loop through lines
while (my $line = <$fh>) {
	chomp($line);
	my @msg = split /;/ , $line;
	SWITCH: {
		if ($msg[2] == "0") {
			#OK
			$p->add_message(OK, "$msg[1] - $msg[4]");
			last SWITCH;
		};	
		if ($msg[2] == "1") {
			#Warning
			$p->add_message(WARNING, "$msg[1] - $msg[4]");
			last SWITCH;
		};	
		if ($msg[2] == "2") {
			#Critical
			$p->add_message(CRITICAL, "$msg[1] - $msg[4]");
			last SWITCH;
		};	
		if ($msg[2] == "3") {
			#Unknown
			$p->add_message(UNKNOWN, "$msg[1] - $msg[4]");
			last SWITCH;
		};	
	#Default
	$p->add_message(UNKNOWN, "Invalid status code");

	}
}
close  $fh;

# Output
($code, $message) = $p->check_messages();
$p->plugin_exit( $code, $message );
