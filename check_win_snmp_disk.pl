#!/usr/bin/perl


# Enhanced by: pashol
# Date: 30/7/2015
# Enhanced by: Alexander Tikhomirov and Stanislav German-Evtushenko
# Date: 18/04/2014
# Enhanced by: Anatoly Rabkin
# Date: 27/07/2009
# Based on original script:
# Author: Dan Capper
# Date: 13/11/2007
# check_win_snmp_disk.pl [address] [community-name] [logical disk] [warn-level] [critical-level]
# Based on original script:
# Author : jakubowski Benjamin
# Date : 19/12/2005
# check_win_snmp_disk.pl SERVEUR COMMUNITY

# ------------ "Nearest" routines (round to a multiple of any number)
# Copied from Math::Round on cpan.org
# Math::Round was written by Geoffrey Rommel GROMMEL@cpan.org in October 2000.

# ------------ "getnewlevel" routine (Magic adaption of percentage levels for especially large or small filesystems)
# Copyright Mathias Kettner 2013             mk@mathias-kettner.de
# Is part of Check_MK.
# The official homepage is at http://mathias-kettner.de/check_mk.


sub nearest {
 my ($targ, @inputs) = @_;
 my @res = ();
 my $x;

 $targ = abs($targ) if $targ < 0;
 foreach $x (@inputs) {
   if ($x >= 0) {
      push @res, $targ * int(($x + $half * $targ) / $targ);
   } else {
      push @res, $targ * POSIX::ceil(($x - $half * $targ) / $targ);
   }
 }
 return (wantarray) ? @res : $res[0];
}

sub getnewlevel {
 my $RSIZE = shift;
 my $MLEVEL = shift;
 
	$MLEVEL = $MLEVEL/100;
        $HGBSIZE = $RSIZE/$MNORMSIZE;
        $FELTSIZE = $HGBSIZE**$MAGIC;
        $SCALE=$FELTSIZE/$HGBSIZE;
        $NEWLEVEL = 1- ((1-$MLEVEL))*$SCALE;
	$NEWLEVEL = $NEWLEVEL*100;

 return ($NEWLEVEL);
}

$STATE_OK = 0;
$STATE_WARNING = 1; 
$STATE_CRITICAL = 2;
$STATE_UNKNOWN=3;
#$STATE_UNKNOWN = 255;

# IEC Multipliers
$TEBI = 1099511627776;
$GIBI = 1073741824;
$MEBI = 1048576;
$KIBI = 1024;

#Magic Number Hard Settings
$MAGIC=1;
$MNORMSIZE=20*$GIBI;

$snmpwalk=`which snmpwalk`;
chomp($snmpwalk);
$snmpget=`which snmpget`;
chomp($snmpget);
$snmpstatus=`which snmpstatus`;
chomp($snmpstatus);

#print "SNMPWALK: '$snmpwalk'\n";

if ($#ARGV + 1 < 4) {
	print "Enhanced check_win_snmp_disk.pl by Dan Capper based on original script by jakubowski Benjamin\n";
	print "Reports disk usage of Windows systems via snmp to nagios\n";
	print "\n";
	print "usage:\n";
	print "check_win_snmp_disk.pl <address> <community-name> <warn-level> <critical-level>\n";
	print "Where:\n";
	print "[address]	= ip address or name of server to check\n";
	print "[community-name] = SNMP community name with at least READ ONLY rights to server\n";
	print "[warn-level]	= Percentage full before return warning level to nagios\n";
	print "[critical-level] = Percentage full before return critical level to nagios\n";
	print "[magic] =  Magic adaption of percentage levels for especially large or small filesystems\n";
	print "For example the command:\n";
	print "./check_win_snmp_disk.pl 10.0.0.10 public 80 90 0.7\n";
	print "Will check disk All disks ('C:', 'D:' etc.) on the server at '10.0.0.10' using snmp community name 'public'. Warn at 80% full, Critical at 90% full\n";
	exit $STATE_UNKNOWN;
}

if (@ARGV[1] =~ m/\w+/) {
	$COMMUNITYNAME=@ARGV[1];
} else {
	print "ERROR: community-name argument not in correct format\n";
	print "Execute with no parameters to see usage information\n";
	exit $STATE_UNKNOWN;
}

if (@ARGV[0] =~ m/((\d{1,3}\.){3}\d{1,3})|(\w+)/) {
	$SERVER = @ARGV[0];
	$TEST=`$snmpstatus -v 1 $SERVER -c $COMMUNITYNAME -t 5 -r 0 2>&1`;
	chomp($TEST);
	#print "Test:\n$TEST\n";
	if ( ( $TEST =~ /Timeout: No Response from/ ) || ( $? > 0 ) ){
		print "SNMP to $SERVER is not available\n";
		print "Check command: '$snmpstatus -v 1 $SERVER -c $COMMUNITYNAME -t 5 -r 0'\n";
		print "Result: $TEST\n";
		exit $STATE_UNKNOWN;
	}
	if ( $TEST !~ /windows/i ){
		print "This host is not a WINDOWS machine!!!!\n";
		exit $STATE_UNKNOWN;
	}
} else {
	print "ERROR: address argument not in correct format\n";
	print "Execute with no parameters to see usage information\n";
	exit $STATE_UNKNOWN;
}

#if (@ARGV[2] =~ m/\d{1,2}/) {
#	$LDISK=@ARGV[2];
#} else {
#	print "ERROR: logical disk argument not in correct format\n";
#	print "Execute with no parameters to see usage information\n";
#	exit $STATE_UNKNOWN;
#}

if (@ARGV[3] =~ m/\d{1,3}/ and @ARGV[3] <= 100) {
	$CRITICAL=@ARGV[3];	
} else {
	print "ERROR: critical argument not in correct format\n";
	print "critical level must no more than 100\n";
	print "Execute with no parameters to see usage information\n";
	exit $STATE_UNKNOWN;
}
 
if (@ARGV[2] =~ m/\d{1,3}/ and @ARGV[2] <= 100 and @ARGV[2] <= $CRITICAL) {
	$WARN=@ARGV[2];	
} else {
	print "ERROR: warning-level argument not in correct format\n";
	print "warning-level must no more than 100 and less than critical level\n";
	print "Execute with no parameters to see usage information\n";
	exit $STATE_UNKNOWN;
}

if (@ARGV[4] =~ m/\d{1,3}/) {
	$MAGIC=@ARGV[4];	
}

$THRESHOLDS="(WARN: $WARN% / CRIT: $CRITICAL%)";
$OUTPUT="";
$ERROUTPUT="";
$PERFOUTPUT="";
$LONGOUTPUT="";
$PCTUSED=0;
$EXIT_CODE=0;

# Used Space
#@LDISKS=`$snmpwalk -v 1 -c $COMMUNITYNAME $SERVER HOST-RESOURCES-MIB::hrStorageDescr | grep "Serial Number" | awk '{print \$1}' | awk -F. '{print \$2}'`;
@LDISKS=`$ snmpwalk -O n -v 1 -c $COMMUNITYNAME $SERVER HOST-RESOURCES-MIB::hrStorageType -t 5 | grep ' .1.3.6.1.2.1.25.2.1.4\$' | awk '{print \$1}' | grep -o '[^.]*\$'`;
@LDISKS=grep(s/\n//, @LDISKS);

foreach $LDISK (@LDISKS){
	$DISKNAME=`snmpget -v 1 $SERVER -c $COMMUNITYNAME HOST-RESOURCES-MIB::hrStorage.hrStorageTable.hrStorageEntry.hrStorageDescr.$LDISK -t 5 | awk -F: '{print \$4}'`;
	$DISKNAME =~ s/ //g;
	$DISKNAME =~ s/\n//g;

        if ($DISKNAME =~ m/\d+/ ) {
                print "ERROR : Unexpected result from snmpget - Wrong Disk name: '$DISKNAME'.\n";
                exit $STATE_UNKNOWN;
        }

	$RAWUSED=`$snmpget -v 1 $SERVER -c $COMMUNITYNAME HOST-RESOURCES-MIB::hrStorage.hrStorageTable.hrStorageEntry.hrStorageUsed.$LDISK -t 5| awk '{ print \$4 }'`;
	$RAWUSED =~ s/\n//g;
	if ($RAWUSED !~ m/\d+/) {
		print "ERROR : Unexpected result from snmpget\n";
		exit $STATE_UNKNOWN;
	}
	
	# Size of disk
	$RAWSIZE=`$snmpget -v 1 $SERVER -c $COMMUNITYNAME HOST-RESOURCES-MIB::hrStorage.hrStorageTable.hrStorageEntry.hrStorageSize.$LDISK -t 5| awk '{ print  \$4  }'`;
	$RAWSIZE =~ s/\n//g;
	if ($RAWSIZE !~ m/\d+/) {
		print "ERROR : Unexpected result from snmpget\n";
		exit $STATE_UNKNOWN;
	}
	
	# GET BYTE VALUE FOR DISK SYSTEM (512;1024;2048;4096)
	$VALUE=`$snmpget -v 1 $SERVER -c $COMMUNITYNAME HOST-RESOURCES-MIB::hrStorage.hrStorageTable.hrStorageEntry.hrStorageAllocationUnits.$LDISK -t 5 | awk '{ print \$4 }'`;
	
	$VALUE =~ s/\n//g;
	if ($VALUE !~ m/\d+/) {
		print "ERROR : Unexpected result from snmpget\n";
		exit $STATE_UNKNOWN;
	}
	
	# Calculate Free Space
	
	$RAWFREE=$RAWSIZE-$RAWUSED;
		
	# Calculate percentage used
	
	SWITCH: {
		if ($RAWSIZE * $VALUE > $MNORMSIZE) {
			$PERCENTUSED = nearest(.01, $RAWUSED/$RAWSIZE * 100);
			$WARN = getnewlevel($RAWSIZE*$VALUE, $WARN);
			$WARNRAWSIZE = $RAWSIZE*$WARN/100;
			$CRITICAL = getnewlevel($RAWSIZE*$VALUE, $CRITICAL);
			$CRITRAWSIZE = $RAWSIZE*$CRITICAL/100; last SWITCH;
		};	
		if ($RAWSIZE > 0) {
			$PERCENTUSED = nearest(.01, $RAWUSED/$RAWSIZE * 100);
			$WARNRAWSIZE = $RAWSIZE/100*$WARN;
			$CRITRAWSIZE = $RAWSIZE/100*$CRITICAL; last SWITCH;
		};
		$PERCENTUSED = 0;
		$WARNRAWSIZE = 0;
		$CRITRAWSIZE = 0;
	}
	
	# Calculate human-readable total space, used space, free space
	
	SWITCH: {
		if ($RAWSIZE * $VALUE >= $TEBI)	{ 
			$TOTAL = nearest(.001, $RAWSIZE * $VALUE/($TEBI));
			$USED = nearest(.001, $RAWUSED * $VALUE/($TEBI));
			$FREE = nearest(.001, $RAWFREE * $VALUE/($TEBI));
			$WARNSIZE = nearest(.001, $WARNRAWSIZE * $VALUE/($TEBI));
			$CRITSIZE = nearest(.001, $CRITRAWSIZE * $VALUE/($TEBI));
			$TOTALUNITS = "TiB"; last SWITCH;
		};
		if ($RAWSIZE * $VALUE >= $GIBI)	{ 
			$TOTAL = nearest(.01, $RAWSIZE * $VALUE/($GIBI));
			$USED = nearest(.01, $RAWUSED * $VALUE/($GIBI));
			$FREE = nearest(.01, $RAWFREE * $VALUE/($GIBI));
			$WARNSIZE = nearest(.01, $WARNRAWSIZE * $VALUE/($GIBI));
			$CRITSIZE = nearest(.01, $CRITRAWSIZE * $VALUE/($GIBI));
			$TOTALUNITS = "GiB"; last SWITCH;
		};
		if ($RAWSIZE * $VALUE >= $MEBI)	{
			$TOTAL = nearest(.1, $RAWSIZE * $VALUE/($MEBI));
			$USED = nearest(.1, $RAWUSED * $VALUE/($MEBI));
			$FREE = nearest(.1, $RAWFREE * $VALUE/($MEBI));
			$WARNSIZE = nearest(.1, $WARNRAWSIZE * $VALUE/($MEBI));
			$CRITSIZE = nearest(.1, $CRITRAWSIZE * $VALUE/($MEBI));
			$TOTALUNITS = "MiB"; last SWITCH;
		};
		if ($RAWSIZE * $VALUE >= $KIBI)	{
			$TOTAL = nearest(.1, $RAWSIZE * $VALUE/($KIBI));
			$USED = nearest(.1, $RAWUSED * $VALUE/($KIBI));
			$FREE = nearest(.1, $RAWFREE * $VALUE/($KIBI));
			$WARNSIZE = nearest(.1, $WARNRAWSIZE * $VALUE/($KIBI));
			$CRITSIZE = nearest(.1, $CRITRAWSIZE * $VALUE/($KIBI));
			$TOTALUNITS = "KiB"; last SWITCH;
		};
		if ($RAWSIZE > 0)	{
			$TOTAL = nearest(.1, $RAWTOTAL * $VALUE);
			$USED = nearest(.1, $RAWUSED * $VALUE);
			$FREE = nearest(.1, $RAWFREE * $VALUE);
			$WARNSIZE = nearest(.1, $WARNRAWSIZE * $VALUE);
			$CRITSIZE = nearest(.1, $CRITRAWSIZE * $VALUE);
			$TOTALUNITS = "B"; last SWITCH;
		};
		$TOTAL = 0;
		$USED = 0;
		$FREE = 0;
		$WARNSIZE = 0;
		$CRITSIZE = 0;
	}
	
	if ( $PERCENTUSED < $WARN ) { 
		$LONGOUTPUT.="DISK: $DISKNAME(id: $LDISK) - OK : Percent Used : $PERCENTUSED% $THRESHOLDS, Total : $TOTAL $TOTALUNITS, Used : $USED $TOTALUNITS,  Free : $FREE $TOTALUNITS\n";
		$PERFOUTPUT.="\'Disk $DISKNAME\'=$USED$TOTALUNITS;$WARNSIZE;$CRITSIZE;0;$TOTAL \'Disk $DISKNAME\'=$PERCENTUSED%;$WARN;$CRITICAL ";
		$OUTPUT.="DISK $DISKNAME - OK (Used: $PERCENTUSED%), ";
		if ( ! $EXIT_CODE ){
			$ERROUTPUT="DISK USAGE OK:";
		}
		#exit $STATE_OK; 
		next;
	}
	
	if ( $PERCENTUSED < $CRITICAL ) { 
		$LONGOUTPUT.="DISK: $DISKNAME(id: $LDISK) - WARNING : Percent Used : $PERCENTUSED% $THRESHOLDS, Total : $TOTAL $TOTALUNITS, Used : $USED $TOTALUNITS,  Free : $FREE $TOTALUNITS\n"; 
		$PERFOUTPUT.="\'Disk $DISKNAME\'=$USED$TOTALUNITS;$WARNSIZE;$CRITSIZE;0;$TOTAL \'Disk $DISKNAME\'=$PERCENTUSED%;$WARN;$CRITICAL ";
		$OUTPUT.="DISK $DISKNAME - WARNING (Used: $PERCENTUSED%), ";
		if ( $EXIT_CODE < $STATE_WARNING ){
			if ( $PCTUSED <= $PERCENTUSED ){
				$ERROUTPUT="DISK USAGE WARNING:";
				$PCTUSED=$PERCENTUSED;
			}
			$EXIT_CODE=$STATE_WARNING;
		}
		#exit $STATE_WARNING;
		next;
	}
	
	if ( $PERCENTUSED >= $CRITICAL ) {
		$LONGOUTPUT.="DISK: $DISKNAME(id: $LDISK) - CRITICAL : Percent Used : $PERCENTUSED% $THRESHOLDS, Total : $TOTAL $TOTALUNITS, Used : $USED $TOTALUNITS,  Free : $FREE $TOTALUNITS\n";
		$PERFOUTPUT.="\'Disk $DISKNAME\'=$USED$TOTALUNITS;$WARNSIZE;$CRITSIZE;0;$TOTAL \'Disk $DISKNAME\'=$PERCENTUSED%;$WARN;$CRITICAL ";
		$OUTPUT.="DISK $DISKNAME - CRITICAL (Used: $PERCENTUSED%), ";
                if ( $EXIT_CODE <= $STATE_CRITICAL ){
			if ( $PCTUSED < $PERCENTUSED ){
				$ERROUTPUT="DISK USAGE CRITICAL:";
				$PCTUSED=$PERCENTUSED;
			}
                        $EXIT_CODE=$STATE_CRITICAL;
                }
		#exit $STATE_CRITICAL;
	}
}#foreach	
#print "ERROR : Unexpected Results : Percent Used : $PERCENTUSED%, Total : $TOTAL $TOTALUNITS, Used : $USED $USEDUNITS,  Free : $FREE $FREEUNITS\n"; 
#exit $STATE_UNKNOWN;

print "$ERROUTPUT $OUTPUT|$PERFOUTPUT\n";
#print "$LONGOUTPUT";
exit $EXIT_CODE;
