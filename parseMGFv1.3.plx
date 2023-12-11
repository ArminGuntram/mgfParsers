#!/usr/bin/env perl

use strict;
use warnings;
use File::Basename;

#This is my change

my $help = "Program parses mgf and outputs a sample-scan peaklist in long format. 1st arg is a full path to an mgf file. output file is created using input file name as base. outfiles have a header, unless you specify 'header=False' as 2nd arg \n. Full program doc under program name in overleaf dir.";
#runtime is less than 30 sec per file 

if (@ARGV < 1){
	        die "Not enough arguments given, please provide an input file as 1st arg. For help, type parseMGFvx.x.pl -h or --help\n";
}
if ($ARGV[0] =~ /-h|--help/){
	print $help;
	exit();
}

my $infileMGF = $ARGV[0]; #where file must be the full readlink path and name of the an mgf file if you please	
#print "$infileMGF\n";
#my($filename, $dirs, $suffix) = fileparse ($infileMGF);
#print "$dirs\n";
our $baseName = basename($infileMGF, ".mgf"); #basename takes two args, the filename and the suffix

our $trunc_arg; # "sprintf" "precision" "argument" for use later in subroutine mzMod
unless ($ARGV[1]){
	$trunc_arg = "NA";	
}else{
	die ("$ARGV[1] is not integer, program expects integer.Args are positional"), unless (int($ARGV[1]));  
	$trunc_arg = $ARGV[1];
	$baseName = "$baseName"."_$trunc_arg"."dec";
}

my $printHeader = 0; #header is TRUE by default
if ($ARGV[2]){ #if you give anything as 3rd arg it will asume header is false
	$printHeader = 1;
}

#print "$baseName\n"; #prints msClust_S3_kfedDay1_300_0

#sys commands
my $beginIons = `grep 'BEGIN IONS' $infileMGF |wc -l`;
my $endIons = `grep 'END IONS' $infileMGF |wc -l`;
my $amtScans = `grep 'scan=' $infileMGF |wc -l`;
#print "$beginIons";
#my $syst = `hostname`; #what system are you working 
#$syst =~ s/\?//;

open (LOG, ">$baseName\_longfrmtPkListSampleScan.log") or die ("couldnt open LOG for writing");

if ( ($beginIons != $endIons) or ($endIons != $amtScans) ){
	print LOG "NOT EQUAL: beginions not equal to end ions or amount scan count for file: $infileMGF\n";
	print "NOT EQUAL: beginions not equal to end ions or amount scan count for file: $infileMGF\n exiting program... $infileMGF not processed\n";
	exit();
	#print "NOT EQUAL: beginions not equal to end ions or amount scan count for file: $infileMGF\n";
}else{
	print LOG "EQUAL: beginions equal to endIOns equal to amount scan count for file: $infileMGF\n";
}

open (P, ">$baseName\_longfrmtPkListSampleScan.tsv") or die ("couldnt open P for writing");
if ($printHeader == 0){ #
	#print header
	print P join ("\t", "mz", "sample_id", "intensity" ), "\n";
}else{
	#do nothing
}

sub parseTitle{ #local scope
	my $titleLine = $_[0];
	#get full sample name
	my @title = split(/\s/, $titleLine);
	#print "$title[1]\n"; #returns File:"Easy_nLC_2ug_Kalanchoe_036_StageTip_AC35cm_01.raw",
	#get scan num only - always in same position
	my @file = split(/\_/, $title[1] );
	##print "$file[4]\n"; # returns sample number eg. "036"
	my $sampleNum = $file[4];
	#get scan number
	#print "$title[4]\n"; # returns < scan=9809" >
	my ($pref, $scanNumber) = split(/=/, $title[4]);
	#removed the double quote
	$scanNumber =~ s/"//;
	#print "$scanNumber\n";
	#return ($sampleNum, $scanNumber);
	$sampleNum = "Sample$sampleNum";
	my $ss_id = join ("_",$sampleNum, $scanNumber); #ss id is Sample-Scan
	return $ss_id;
}	
sub mzAsString{
	my $mzline = $_[0];
	my ($mz,$intens) = split (/\s/,$mzline);
	my $mzAsString = $mz;
	$mzAsString =~ s/\./_/; #replace the decimal point with an undesrcore 
	$mzAsString = "mz_$mzAsString";
	return ($mzAsString, $intens);
}
sub mzTrunc{
	my $mzline = $_[0];
	my $places = $_[1];
	my ($mz,$intens) = split (/\s/,$mzline);
	my $factor =10**$places;
	my $mz_trunc = $mz;
	$mz_trunc = int($mz *$factor) / $factor ;
	$mz_trunc =~ s/\./_/; #replace the decimal point with an undesrcore 
	$mz_trunc = "mz_$mz_trunc";
	return ($mz_trunc, $intens);
}
my $scanNumRef;
open(IF, "$infileMGF") or die ("couldnt open $infileMGF for reading");
my $switch=0;#switch off by default
while(<IF>){
	chomp;
	my $l = $_;
	#chomp $l;
	#chop($l) if ($l =~ m/\r$/); #tried to remove windows carr return - didn't work	
	our $ss_id; #we need access to this variable for every mz of a begin ions block. "ss_id is short for sample_scan_id"
	if ($l =~ /^BEGIN IONS/){
		$switch=1; #flips the switch from zero to one
		next; #switch flipped so we are done with this line
		#print "switch is equal to $switch\n";
	}
	
	if ($switch == 1){ #if the switch is = 1 it means we have access to the lines in between a "begin ions"and "end ions" segement of a file - ie a single MS2 spectrum
		if ($l =~ /TITLE=*/){ 
			$ss_id = parseTitle($l);
			#print "$ss_id\n";
			$scanNumRef->{$ss_id}=1;
			next; #switch is 1 , we got what we need from the line so can move on
		}
		#print "$ss_id\n";
		#print "$l\t$ss_id\n";
		#next if ($l =~ /^BEGIN IONS/);
		#next if ($l =~ /^TITLE/);
		next if ($l =~ /^RTINSECONDS/) or ($l =~ /^CLUSTER_SIZE/) or ($l =~ /^CHARGE/) or ($l =~ /^PEPMASS/) or ($l =~ /^PRECURSOR_INTENSITY/) or ($l =~ /^END IONS/) or ($l =~ /^$/);
		
		if ($trunc_arg =~ "NA"){
			my ($mzAsString, $intens) = mzAsString($l); # default no truncation
			#print "$mz_rnd\t$ss_id\n";
			#print "$mzround\t$ss_id\n";
			#print join ("\t", $mzround, $intens, $ss_id ), "\n";
			print P join ("\t", $mzAsString, $ss_id, $intens ), "\n";
		}
		else{
			my ($mzTrunc, $intens) = mzTrunc($l, $trunc_arg); # with truncation
			#print "$mzTrunc\n";
			print P join ("\t", $mzTrunc, $ss_id, $intens ), "\n";
		}
		
		#my ($mzTrunc, $intens) = mzTrunc($l, "2"); # with truncation
		#print "$mzTrunc\n";
		#print P join ("\t", $mzAsString, $ss_id, $intens ), "\n";

		#if ($_ =~ /RTINSECONDS=(\d+\.\d+)/){ 
			# do nothing for now
		# 	#print "$1\n";
		# 	my $rt = $1;
		# 	#print P "$rt\t";
		#}

		#if ($_ =~ /PEPMASS=(\d+\.\d+)/){ #where PEPMASS is th parent ion
		# 	# do nothing for now
			#print "$1\n";
		# 	my $rnd_mass = sprintf("%.4f",$1);
		# 	#print P "$rnd_mass\t";
		#}
		#if ($_ =~ /CHARGE=(\d\+)/){ 
			# do nothing for now 	
		#print "$1\n";
		# 	my $charge = $1;
		# 	#print P "$charge\n";
		#}
	}
	if (/^END IONS/){		
		$switch=0;
		#print "switch is equal to $switch\n";
		#next; ##switch flipped back to zero so we are done with this line #not working 
	}
}
close(IF);
close(P);
#my $ss_count = (%$scanNumRef);
my $ss_count = scalar (keys($scanNumRef));
#print "$ss_count\t$beginIons\n"; check ok 
if ($beginIons != $ss_count){
	print "begin ions not equal to scanNumber afer parsing\n";
	print LOG "begin ions not equal to scanNumber afer parsing - check the output file: $baseName\_longfrmtPkListSampleScan.tsv\n";
}

#my $ss_count = $scanNumRef;
#print "$ss_count\n";
close(LOG);
