#!/bin/bash

# load param
SCRIPT_DIR=`dirname $0`
. ${SCRIPT_DIR}/../../.env
date=`date +%Y-%m-%d --date '1 day ago'`

# load authkey
. ${SCRIPT_DIR}/.authkey

# load web/base
. ${ROOT}/web/base

# make statistics
$ROOT/util/scripts/sumup.sh type:line sumup_key:uniq_access frequency:daily title:pv set_time:"$date" \
global_filter:"$date" databox:web_analyzer

$ROOT/util/scripts/sumup.sh type:line sumup_key:attack frequency:daily title:attack set_time:"$date" \
global_filter:"$date" databox:web_analyzer

# sync to repilca hosts
if [ "$cluster_server" ];then
  if [ ! "$master" ];then
    for replica in $replica_hosts
    do
      sudo -u small-shell scp -i /home/small-shell/.ssh/id_rsa $ROOT/util/statistics/rawdata/* small-shell@${replica}:$ROOT/util/statistics/rawdata/
      sudo -u small-shell scp -i /home/small-shell/.ssh/id_rsa $ROOT/util/statistics/graph/* small-shell@${replica}:$ROOT/util/statistics/graph/
    done
  fi
fi

exit 0
