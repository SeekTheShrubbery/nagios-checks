#!/usr/bin/perl -w
 
use strict;
use WWW::Mechanize;
use JSON -support_by_pp;
use Data::Dumper;
use FindBin;
use lib "$FindBin::Bin/../perl/lib";
use Monitoring::Plugin;
use POSIX qw( strftime );

# Settings
my $CITY = "Luzern";
my $LANG = "en";

# Declaration
my ($code,$message);

# Main
my $p = Monitoring::Plugin->new( );
fetch_json_page("http://api.openweathermap.org/data/2.5/weather?q=$CITY&lang=$LANG&units=metric");
($code, $message) = $p->check_messages();
$p->plugin_exit( $code, $message );

# Sub
sub fetch_json_page
{
  my ($json_url) = @_;
  my $browser = WWW::Mechanize->new();
  $browser->proxy(['http'], '');
  eval{
    # download the json page:
    #print "Getting json $json_url\n";
    $browser->get( $json_url );
    my $content = $browser->content();
    my $json = new JSON;
 
    # these are some nice json options to relax restrictions a bit:
    my $json_text = $json->allow_nonref->utf8->relaxed->escape_slash->loose->allow_singlequote->allow_barekey->decode($content);
	
	#print Dumper $json_text;
	#print $json_text->{main}{temp};
	#print $json_text->{weather}[0]{description};
	my $sunrise = strftime("Sunrise %H:%M", localtime($json_text->{'sys'}{'sunrise'}));
	my $sunset = strftime("Sunset %H:%M", localtime($json_text->{'sys'}{'sunset'}));
	my $output = $CITY . " - ". $json_text->{weather}[0]{description}. ". $sunrise - $sunset";

	SWITCH: {
		if ($json_text->{weather}[0]{main} eq "Rain") {
			#Rain
			$p->add_message(CRITICAL, $output);
			last SWITCH;
		};
		if ($json_text->{weather}[0]{main} eq "Snow") {
			#Snow
			$p->add_message(WARNING, $output);
			last SWITCH;
		};
		if ($json_text->{weather}[0]{main} eq "Clouds") {
			#Clouds
			$p->add_message(OK, $output);
			last SWITCH;
		};
		if ($json_text->{weather}[0]{main} eq "Mist") {
			#Rain
			$p->add_message(OK, $output);
			last SWITCH;
		};		
		
		#Default
		$p->add_message(OK, $output);
	}
		
	# add perf data
	$p->add_perfdata(
		label => "temp",
		value => $json_text->{main}{temp},
		uom => "C"
    );
	
	if (defined $json_text->{'rain'}{'1h'}) {
		$p->add_perfdata(
			label => "rain",
			value => $json_text->{'rain'}{'1h'},
			uom	  => "mm",
			min   => 0);
	}
	
	$p->add_perfdata(
		label => "windspeed",
		value => $json_text->{'wind'}{'speed'},
		uom	  => "m\/s",	
		min   => 0
	);
	$p->add_perfdata(
		label => "pressure",
		value => $json_text->{'main'}{'pressure'},
		uom	  => "hPa"				
	);
	$p->add_perfdata(
		label => "humidity",
		value => $json_text->{'main'}{'humidity'},
		uom	  => "\%",
		min   => 0,
		max   => 100
	);

  };
  # catch crashes:
  if($@){
    $p->plugin_die("[[JSON ERROR]] JSON parser crashed! $@\n");
  }
}
