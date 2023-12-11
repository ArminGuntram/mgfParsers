#!/usr/bin/env perl
# takes the mgf files, which contain MS2 scan content, gets TITLE, RT, PEPMASS, PEP-INTENSITY, CHARGE line info
# prints a file with only the selected content on a single line, the outfilename is the same as the original input but with a new suffix. Effectively reduces a mgf to only a list of key mgf info that I can match against other files. 
# Example to gen a master for submit: find test/orig_mgf/ -maxdepth 1 -name '*.mgf' |xargs -I {} readlink -f {} |xargs -I {} echo parse_mgf_for_title_nd_rt.plx {} >master_mgf_parse.txt
use strict;
use warnings;
use File::Basename;

my $file = $ARGV[0]; #where file must be the full readlink path and name of the an mgf file if you please	
#print "$file\n";
my $syst = $ARGV[1];
#my @tmp = split (/\./, $file);
#my $base = $tmp[0];
#print $base."\n";
my ($baseName,$path,$suffix) = fileparse($file, qr/\.[^.]*/);
#print "$baseName\n";
#print "$path\n";
#print "$suffix\n";

my $beginions = `grep 'BEGIN IONS' $file |wc -l`;
my $amt_scans = `grep 'scan=' $file |wc -l`;
#print "$beginions";
open (LOG, ">$baseName\_mgf_scanid_scannum_with_mz.log.$syst.txt") or die ("couldnt open LOG for writing");
if ($beginions != $amt_scans){
	print LOG "NOT EQUAL: beginions not equal to amount scan count for file: $file\n";
}else{

	print LOG "EQUAL: beginions equal to amount scan count for file: $file\n";
}

open (P, ">$baseName\_PrecurorSummaryPerScan.$syst.txt") or die ("couldnt open P for writing");
open (H, ">headerLine_$baseName\_PrecurorSummaryPerScan.$syst.txt") or die ("couldnt open H for writing");
open(IF, "$file") or die ("couldnt open $file for reading");
my $switch=0;#switch off by default
my $scan_index=0;
my $count =0; #counter for how many times scan number and scan index number are equal for this file, to be printed to file

#print header to outfile
print H join ("\t", "full_mgf_titleLine", "fileNameClean", "scanNum", "rtInSeconds","preCurPepMass", "preCurIntensity", "charge" ),"\n";  

while(<IF>){
chomp;
	if (/^BEGIN IONS/){
	$switch=1;
	#print "switch is equal to $switch\n";
	}
	if ($switch == 1){
	
		if ($_ =~ /^TITLE=/){
			#print P "$_ ";
			#write yuor file herea
			my $fullTitleLine = $_;
			my ($title, $fileName, $natid, $cnum, $scanumber)=split(/\s/,$_);
			$scanumber =~ s/\"//;
			#cleanup filename
			$fileName =~ s/File:"Easy_nLC_2ug_//;
			$fileName =~ s/_StageTip_AC35cm_01\.raw",//;

			my ($text, $scanNumClean) = split(/=/,$scanumber);
			#print P "$f\t$scanumber\tscan_index=$scan_index\n"; 
			print P join ("\t", $fullTitleLine, $fileName, $scanNumClean ),"\t";
			#print join ("\t",$f,$scanumber,$scan_index), "\t";
			if ($scan_index == $scanNumClean){
				$count++;
			}
		}
		if ($_ =~ /^RTINSECONDS/){
			my ($pref, $rtInsec) = split(/=/,$_);
			print P "$rtInsec\t";
		}
		#if ($_ =~ /PEPMASS=(\d+\.\d+)/){
		if ($_ =~ /^PEPMASS=/){
			if ($_ =~ /\s/){ #if-else should capture instance of pepmass without intensities 
				my ($pepMass, $pepIntensity)=split(/\s/,$_);
				#print "$pepMass\t$pepIntensity\n";
				my ($pref, $pepMassFloat) = split(/=/,$pepMass);
				print P join ("\t", $pepMassFloat, $pepIntensity), "\t";
				#print P "$rnd_mass\n";
			}else{
				my $pepMass = $_;
				my $pepIntensity = "NA";
				#print "$pepMass\t$pepIntensity\n";
				my ($pref, $pepMassFloat) = split(/=/,$pepMass);
				print P join ("\t", $pepMassFloat, $pepIntensity), "\t";
				#print P "$rnd_mass\n";
			}

		}
		
		if ($_ =~ /^CHARGE/){
			my ($pref, $charge) = split(/=/,$_);
			print P "$charge\n";
		}
		
	}
	if (/^END IONS/){		
	$switch=0;
	#print "switch is equal to $switch\n";
	$scan_index++;
	}
	#if ($switch == 0){
	#}
}
close(IF);
print LOG "The number of times scanindex and scannumber is the same for this file: $count\n";
close(P);
close(H);
close(LOG);
