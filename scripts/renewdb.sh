#!/usr/bin/env bash

# use github version
PATH="~/src/mdbtools/mdbtools-github/src/util:$PATH"

db=~/LunaDB.mdb
db=/mnt/B/bea_res/Database/LunaDB.mdb
sqldb=luna.sqlite3.db
export TIME="%S %U %P"  

# cannot read db, mabye its not mounted
#[ ! -r $db ] && sudo mount.cifs //OACRES3/rcn/ ~/remotes/B/ -o credentials=~/.cifs_credentials,iocharset=utf8,uid=1000,gid=100,rw,nobrl
# still can't read it, die
[ ! -r $db ] && echo "cannot read $db!" && exit


cd $(dirname $0)

# exits 1 if changes 
# git diff | wc -l                            ###  14
# git diff --exit-code >/dev/null || echo $?  ### echo's 1
git diff --exit-code >/dev/null || git commit -am 'update before running'

# redo every time
[ -d schema/ ] && rm -r schema/
mkdir schema

mdb-schema $db mysql |sed '/^COMMENT/d'  > schema/schema.sqlite3 
mdb-tables -1 $db |while read t; do 
    mdb-export -D "%Y-%m-%d %H:%M:%S" -I mysql $db $t > schema/table-${t}.sqlite3
done
 

# database has changed, update db
if ! git diff --exit-code || [ ! -r $sqldb ] ; then
   [ -r $sqldb ] && rm $sqldb
   echo "populating schema"
   time sqlite3 $sqldb <  schema/schema.sqlite3
   echo "adding data"
   #time cat schema/table-*.sqlite3 | sqlite3 $sqldb
   for f in schema/table-*; do 
    echo $f;
    time sqlite3 $sqldb < $f;
   done
fi

git commit -am "$(date +%F) new DB generated"
