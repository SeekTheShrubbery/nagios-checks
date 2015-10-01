#!/usr/bin/perl
use FindBin;
use lib "$FindBin::Bin/../perl/lib";
use Monitoring::Plugin;
use File::Basename;
use strict;
use warnings;
use WWW::Mechanize;
use Test::More;
use Test::WWW::Mechanize;

#######################
# Settings
#######################
my $url = "https://mywebsite";
my $username = "username";
my $password = "password";
my $link = "Profil";
my $expect_string = "Profil deaktiviert";
my $number_of_tests = 4;

#######################
# Constant
#######################
my $STATE_OK = 0;
my $STATE_WARNING = 1; 
my $STATE_CRITICAL = 2;
my $STATE_UNKNOWN=3;

my $VERSION = 1;
my $PROGNAME = basename($0);
my ($code,$message);
my $state = 0;

#######################
# Main
#######################

my $p = Monitoring::Plugin->new( );
my $t_before = time(); # define start time for perf_data
my $mech = Test::WWW::Mechanize->new;

# Get Page
$state = $mech->get_ok($url,
						{
							timeout => 5
						});
if (!$state) {
	$p->plugin_die("Website not accessible");
}

# Login to page
$mech->submit_form_ok( {
	form_name => "formlogin",
	fields => {
		username => $username,
		password => $password,
		button => "Anmelden",
		}
	}, 'Login to website'
);

# Follow link on page
$state = $mech->follow_link_ok( {text => $link} , "Follow $link link");
if (!$state) {
	$p->add_message(CRITICAL, "Couldn't login, or link not available");
}

# Checking content and preparing exit
if ($mech->content_contains($expect_string)) {
	$p->add_message(OK, "Page content found");
} else {
	$p->add_message(CRITICAL, "Page content NOT found");
}
done_testing($number_of_tests);
my $t_diff = time()-$t_before;
$p->add_perfdata(
     label => "duration",
     value => $t_diff,
     uom => "s"
   );

($code, $message) = $p->check_messages();
$p->plugin_exit( $code, $message );
