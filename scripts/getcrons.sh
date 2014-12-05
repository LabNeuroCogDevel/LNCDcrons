#!/usr/bin/env bash

#
# lists cron tasks for known hosts
# and tracks them
# changes are printed (and emailed when run inside cron)
#
# N.B.: changes in cron (additions/deletions) are likely 
# to require new files be pulled inside src/cron folders
# on the host with changes
#

for uh in foranw@reese overseer@arnold  \
          foranw@wallace overseer@skynet \
          lncd@skynet lncd@arnold \
          luna@MEG; do
 ssh $uh 'crontab -l' > crons/$uh.cron
done

cp ~/src/mesonScripts/meson.crontab crons/kaihwang@meson


# if a cronscript has changed, update it
[ $(svn diff *cron|wc -l) -gt 0  ] && svn diff *cron  && svn ci -m 'autoupdate cron script change'
