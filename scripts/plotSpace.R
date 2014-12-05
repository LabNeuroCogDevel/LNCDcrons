#!/usr/bin/env Rscript
suppressMessages(library(ggplot2))
library(plyr)
#d <- read.table('spaceTable.txt',header=T)

#get basename
file.arg.name <- "--file="
initial.options <- commandArgs(trailingOnly = FALSE)
script.name <- sub(file.arg.name, "", initial.options[grep(file.arg.name, initial.options)])
script.basename <- dirname(script.name)

# get data from bash script
d <- read.table(pipe(paste(script.basename, '/perDrive.sh',sep="")),header=T)

drives<-merge(ddply(d, .(Host),summarize,value=sum(Total)),d)
names(drives)[2]<-'HostTotal'
ymax=max(drives$HostTotal+drives$HostTotal/10)
#drives$ymax=max(drives$HostTotal+drives$HostTotal/10)
percomputer <- ggplot(drives,aes(x=Host))   + 
               # geom_bar(aes(y=HostTotal),fill="grey70") +  # David doesn't like this :)
               geom_bar(  aes(y=Total, group=Mounted),
                          position="dodge",fill="darkgreen", #was grey50
                          stat="identity"
                        ) + 
               geom_bar(  aes(y=Total-Available, group=Mounted, fill=Capacity),
                          position="dodge",stat='identity'
                        ) +  
               geom_text(  aes(y=100, group=Mounted, fill=Capacity,
                               label=Mounted),
                          hjust=0,vjust=.5,position=position_dodge(width=1),stat='identity'
                        ) +  
               geom_text(  aes(y=ymax, group=Mounted, fill=Capacity,
                               label=paste(round(Available,0),' Gb Free',sep="")),
                          hjust=1,vjust=.5,position=position_dodge(width=1),stat='identity'
                        ) +  
               scale_fill_gradient(
                          'Capacity',  
                          low='white',high='darkred',
                          limits=c(0,100)
                         ) +
               scale_y_continuous(limits=c(0,ymax)) +
               coord_flip() + theme_bw() + ggtitle(paste(sep="",'disk space ',date()))

png(paste(script.basename,'/diskSpaceRPlot.png',sep=""))
print(percomputer)
graphics.off() # won't print null device stuff like dev.off() does
