#!/usr/bin/perl
##########
# compare file listings between MRCTR on meson with local raw backup
# 
# TODO:
#  x  Check sort on both meson and arnold work the same way 
#      sort looks good, odd processing files in the raw data (*nii.gz) and unwanted orig. (MoCoSeries/)
#
#  x  Rewrite date when just subject given/check if subject exits in experiment
#     DONE
#
#  o  Make host and base dir user defined (check any binary combination of wallace, arnold, and meson)
#     - check one against meson, do vimdiff <(ssh find) <() to compare wallace and arnold
#     - write another script to do meson <- arnold/wallace
#
#  x  Check file size/hash? 
#        way too expensive, unlikely to be an issues
#
##########
use strict;
use warnings;
use List::Util qw(sum);
#use v5.14;

#total number of scans, and err types of backing up those scans
my %totalCounts=('total' => 0,'error' => 0,'name' => 0,'missing' => 0);

#Meson project ID to lncd Project name 
my %N2P = ('WPC-5744'=>'WorkingMemory','WPC-5640'=>'MultiModal', 'WPC-4951'=>'MRCTR');

#file comparison errors are probably not the result of sort
my $sortCMD="sort -df";


#########
##meson##
#########
#check that we're signed into meson
`meson.expect` if(not `ls $ENV{HOME}/.ssh/master/*meson* 2>/dev/null`);

open my $MasonFilesPipe, "ssh meson 'find /disk/mace2/scan_data/{WPC-5744,WPC-5640,WPC-4951}' |$sortCMD|" or die "Cannot open meson pipe: $!\n";
#open my $MasonFilesPipe, "ssh meson 'find /disk/mace2/scan_data/{WPC-4951}' |$sortCMD|" or die "Cannot open meson pipe: $!\n";

my @ArnoldFiles;

#array counter (for b -- local files)
my $ArnoldIdx = 0;

#if at anytime the files are out of sync
my $errorFlag       = 0;
my $nameConViolFlag = 0;
my $nameFixed       = 0;
my $MRORG           = 0;


#get list of new scan (given scan and project)
sub updateArray{
 #get function inputs
 my ($project,$scan,$suggdate,$path) = @_;
 chomp $scan;

 #clear flags
 $errorFlag       = 0;
 $nameConViolFlag = 0;
 $nameFixed       = 0;
 $MRORG           = $path?1:0;

 #clear only file array
 @ArnoldFiles = ();
 #reset index
 $ArnoldIdx = 0;

 #update count
 $totalCounts{total}++;

 #check name format given by meson
 if($scan !~ m/^\d{5}_\d{8}$/ && ! $path) {
    if($scan =~ m/^\d{5}$/){
       $scan     .= "_$suggdate";
       $nameFixed = 1;
    }
    else {
       #only used if cmp error is found (e.g DNE on arnold)
       $nameConViolFlag=1;
    }
 }

 #set path to default if it wasn't provided
 $path = "/Volumes/T800/Raw/$project/$scan" if ! $path;

 #Get a list of all files in this scan
 #print "updating arnold for $project $scan\n";
 open my $ArnoldFilesPipe, "ssh arnold 'find $path' 2>/dev/null|$sortCMD |" 
    or die "Cannot open arnold pipe: $!\n";

 #skip nii.gz ... they are never in the original raw
 #@ArnoldFiles=<$ArnoldFilesPipe>;
 while(<$ArnoldFilesPipe>){
    if(/nii\.gz/){
       #print "** found a nii.gz **";
       next;
    }

    #remove the suggested part of the name for better comparison
    s/_$suggdate// if $nameFixed;
    push @ArnoldFiles, $_;
 }


 #check there are files for the scan on arnold
 if($#ArnoldFiles == -1) {
   #print "\nEMPTY!\n\n";
   $errorFlag=1;

   #if the name was fixed, the scan still doesnt exist -- don't talk about it being fixed
   $nameFixed=0;
 }

}

#for each file on Mason
while(<$MasonFilesPipe>){
   my @MasonFiles = split "/" ;
   chomp;
   my $mesonFullpath=$_;

   my $scan = $MasonFiles[6];
   my $pr   = $MasonFiles[4];
   $pr      = $N2P{$pr};

   #skip if path isn't long enough or we have an error with this scan (scan is at pos 6)
   next if $#MasonFiles<6 || ($#MasonFiles>6 && $errorFlag);

   #get suggested date from 12.16.2011
   $MasonFiles[5] =~ m/(\d{2})\.(\d{2})\.(\d{4})/;
   my $suggdate = "$3$1$2";

   my $mesonPath = join( "/", @MasonFiles[7..$#MasonFiles] );

   #update if we made it to a new scan
   updateArray($pr,$scan,$suggdate,0) if $#MasonFiles==6;


   #there are more files on meson then on arnold: ERR
   $errorFlag=1 if $ArnoldIdx>$#ArnoldFiles;

   #format the path on arnold for comparision to meson
   my $pathEnd = $MRORG ? "\/$suggdate" : $scan;
   $ArnoldFiles[$ArnoldIdx]=~s/.*$pathEnd(\/+|$)// unless $errorFlag;



   if ( $errorFlag || $ArnoldFiles[$ArnoldIdx] ne $mesonPath) {

      chomp $scan;
      #don't care if
      #  mismatch is becuse MoCoSeries exists on meson but not in Raw
      #  and not already an error
      next if !$errorFlag && $mesonFullpath =~ m/MoCoSeries/;

      #not already an error, is an MRCTR and has no date
      # check MRCR_Orig
      if($ArnoldIdx==0 && $errorFlag && $scan =~ /^\d{5}$/ && $pr eq "MRCTR"){
         #reset warning of empty
         $errorFlag=0;
         #print STDERR "Trying Org for $scan (@ $suggdate)\n";
         updateArray($pr,$scan,$suggdate,"/Volumes/T800/Raw/MRRC_Org/$scan/$suggdate/");
         $totalCounts{total}--;
         
         #check first in path with new list
         $ArnoldFiles[$ArnoldIdx]=~s/.*\/$suggdate(\/|$)// unless $#ArnoldFiles==-1;
         chomp $ArnoldFiles[$ArnoldIdx];
         #print STDERR "\t $#ArnoldFiles\t$errorFlag\n";
         if($#ArnoldFiles>-1 && $ArnoldFiles[$ArnoldIdx] eq $mesonPath){
          $ArnoldIdx++;
          next;
         }
         #print STDERR "\tAnd failed arnod:'$ArnoldFiles[$ArnoldIdx]'\tmeson:'$mesonPath'\n";
      }

      $errorFlag = 1;

      my $arnoldScanPath = "/Volumes/T800/Raw/$pr/$scan";

      #Misname fixed but files don't compare, counted as error (missing file)
      if($nameFixed) {
         print "BADFIX\t$pr\t$scan\tmeson:$mesonFullpath/ $arnoldScanPath/";
         if($ArnoldFiles[$ArnoldIdx]){
            chomp $ArnoldFiles[$ArnoldIdx];
            print "\t$ArnoldFiles[$ArnoldIdx]";
         }
         print "\n";
         $totalCounts{error}++;
      }
      #Badname
      elsif($nameConViolFlag) {
         print "BADNAME\t$pr\t$scan\tmeson:$mesonFullpath\n";
         $totalCounts{name}++;
      }
      #Missing scan
      elsif( $ArnoldIdx == 0 ){
         print "MISSING\t$pr\t$scan\tscp -r meson:$mesonFullpath/ $arnoldScanPath";
         print "_$suggdate" if $scan =~ /^\d{5}$/;
         print "/\n";
         $totalCounts{missing}++;
      }
      #missing file
      else {
         print "COMPERR\t",$MRORG?"MRCR_Org":$pr,"\t$scan at comparison # $ArnoldIdx ";
         #give a little more info if we can
         if($ArnoldFiles[$ArnoldIdx]){
            chomp $ArnoldFiles[$ArnoldIdx];
            print "\tmeson:'$mesonFullpath'\tarnold:'$ArnoldFiles[$ArnoldIdx]'";
         }
         print "\n";
         $totalCounts{error}++;
      }
   }
   $ArnoldIdx++;
}

#last count update
$totalCounts{total}++;

#print counts to stderr if error or missing
my @nums=keys %totalCounts;
print STDERR uc(join("\t",@nums)),"\n",join("\t",@totalCounts{@nums}),"\n" if sum(@totalCounts{'error','missing','name'})>0;
