#!/usr/bin/env bash

#
# lists cron tasks for known hosts
# and tracks them
# changes are printed (and emailed when run inside cron)

# nothing on skynet
#  lncd@skynet overseer@skynet 

for uh in foranw@reese  foranw@wallace\
          overseer@arnold   lncd@arnold \
          luna@MEG; do
 ssh $uh 'crontab -l' > crons/$uh.cron 
done

# cannot log into meson without typing password
# -- use cron in meson to send meson's cron :)
cp ~/src/mesonScripts/meson.crontab crons/kaihwang@meson


# if a cronscript has changed, update the tracked version
! git diff --exit-code crons/*  && git add crons/* && git commit -m 'autoupdate: cron changed on some host'

#[ $(svn diff *cron|wc -l) -gt 0  ] && svn diff *cron  && svn ci -m 'autoupdate cron script change'
