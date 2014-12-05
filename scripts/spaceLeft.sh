#!/usr/bin/env bash

#####
# intended for cron job
# daily:   $0         --> only prints if disks are low
#
# weekly:  $0 print   --> prints even if no disks are low (if arg 1 is "print")
#
#########
#
# ssh's into each machine to do df -h, sorts, checks capacity
# writes output to logfile
# prints to stdout if asked or space is low
#
####

export     logfile=$HOME/log/diskspace.log
export    warnsize=150       #must be GiB units between 0 and 1023 (otherwise prefix G logic doesn't work)
export warnpercent=90        #could still be more left than warn size


#writes free space to logfile
#exits with error if warnsize or warnpercent condition encountered
function isspace {
   (
    #get output for drives of interest
    ssh arnold  'df -h             |grep "/T"'; 
    ssh wallace 'df -h /data/Luna1/|tail -n1';
    ssh skynet  'df -h             |egrep "Connor|Serena"';
   )|
    #parse out the junk, format, and sort
    sed 's:/Volumes/::'   |
    awk '{print $4,$5,$6}'|
    sort -k1h -t"	"      | 
    #write to file, exit with error if low
    perl -slane '

   #open log file
   BEGIN{ use warnings; open $fh, ">$ENV{logfile}" or die "$!";
         $date=`date`;chomp($date);print $fh $date; 
         @warn=();
        } 

   $,="\t";
   print $fh @F[0..2];
   push @warn, $F[2] if (
                          $F[0]=~/^(\d+)(G|K|M)/                #Were talking about GiB or smaller
                             and 
                          ($1< $ENV{warnsize} or $2 ne "G")     #Less than warnsize GiB or smaller than a GiB
                        ) 
                        or 
                        substr($F[1],0,-1) > $ENV{warnpercent}; #Drive is huge, but mostly used

   END{
     if($#warn>-1){
        print "WARNING: low (<$ENV{warnsize}G or <$ENV{warnpercent}%) disk(s):", @warn,"\n";
        exit 1; #exit status says "Problem!"
     }
   }
   '
}

#if there is not space, or we are asked to print
if ! isspace || [ "$1" == "print" ]; then
  cat $logfile 
fi

# either way, track it
cd $(dirname $logfile) && git commit -am "$(date +%F)"
