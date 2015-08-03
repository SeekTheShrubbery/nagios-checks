#!/usr/bin/perl

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

	$HGBSIZE = $RSIZE/$MNORMSIZE;
	$FELTSIZE = $HGBSIZE**$MAGIC;
	$SCALE=$FELTSIZE/$HGBSIZE;
	$NEWLEVEL = 1- ((1-$MLEVEL))*$SCALE;
	$NEWLEVEL = $NEWLEVEL*100;
			
 return ($NEWLEVEL);
}

$MNORMSIZE=20;
$MAGIC=0.6;

$NEW = getnewlevel(50,0.8);

print "$NEW\n";
