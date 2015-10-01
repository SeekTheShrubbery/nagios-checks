#!/usr/bin/perl
##############################################
# Script is to test:
# 1. Access webpage
# 2. Login to page
# 3. Find link "Profil" and follow
# 4. Check for particular content on the profile page
##############################################

use strict;
use warnings;
use WWW::Mechanize;
use Test::More;
use Test::WWW::Mechanize;

#######################
# Settings
#######################
my $url = "http://mywebsite";
my $username = "username";
my $password = "password";
my $link = "Profil";
my $expect_string = "Profil deaktiviert";
my $state = 0;
my $exit_code = 3;
my $number_of_tests = 4;

#######################
# Constant
#######################
my $STATE_OK = 0;
my $STATE_WARNING = 1; 
my $STATE_CRITICAL = 2;
my $STATE_UNKNOWN=3;

#######################
# Main
#######################

my $t_before = time(); # define start time for perf_data
my $mech = Test::WWW::Mechanize->new;

# Get Page
$state = $mech->get_ok($url,
						{
							timeout => 5
						});
if (!$state) {
	print "Website not accessible";
	exit $STATE_CRITICAL;
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
	print "Couldn't login, or link not available";
	exit $STATE_CRITICAL;
}

# Checking content and preparing exit
if ($mech->content_contains($expect_string)) {
	$exit_code = $STATE_OK;
} else {
	$exit_code = $STATE_CRITICAL;
}
done_testing($number_of_tests);
my $t_diff = time()-$t_before;
my $output = "|duration=";
$output .= join('',$t_diff,"s");
print $output;

exit $exit_code;
