#!/bin/bash

# load param
SCRIPT_DIR=`dirname $0`
. ${SCRIPT_DIR}/../../.env
tmp="${SCRIPT_DIR}/tmp"
date=`date +%Y-%m-%d --date '1 day ago'`

# load authkey
. ${SCRIPT_DIR}/.authkey

# load web/base
. ${ROOT}/web/base
log="${www}/log/srvdump.log.1"

# replication check
if [ "$cluster_server" ];then
  if [ ! "$master" ];then
    cat $log > ${tmp}/ssw_integrated_log.tmp
    for replica in $replica_hosts
    do
      sudo -u small-shell scp -i /home/small-shell/.ssh/id_rsa small-shell@${replica}:${log} ${tmp}/
      cat ${tmp}/srvdump.log.1 >> ${tmp}/ssw_integrated_log.tmp
    done
    log=${tmp}/ssw_integrated_log.tmp
  else
    echo "info: log will be analyzed on master server"
    exit 0 
  fi
fi

# analyze log
total_access_num=`cat $log | grep requested | grep -v "requested wrong page" | grep -v css | grep -v favicon.ico | wc -l | tr -d " "`
cat $log | grep requested | grep -v "requested wrong page" | grep -v css | grep -v favicon.ico | $AWK '{print $3}' | sort | uniq > ${tmp}/uniq_access.tmp
attack_num=`cat ${log} | grep -v css | grep -v favicon.ico | grep "requested wrong page" | wc -l` 
apps=`ls ${www}/html |  xargs basename -a`

echo "" > ${tmp}/access_detail
uniq_access_num=0
for app in $apps
do
  if [ "$app" = "index.html" ];then
    num=`grep "requested /" $log | $AWK '{print $3}' | sort | uniq  | wc -l`
  else
    num=`grep "requested $app" $log | $AWK '{print $3}' | sort | uniq  | wc -l`
  fi
  echo "$app:$num" >> ${tmp}/access_detail
  uniq_access_num=`echo "$uniq_access_num + $num" | bc`
done

# dump
echo "total_access:$total_access_num"
echo "uniq_access:$uniq_access_num"
echo "# uniq access pages"
echo "----------------------------------------------------------------"
cat ${tmp}/access_detail
echo "----------------------------------------------------------------"

if [ ! -d ${tmp}/analyzer_dump ];then
  mkdir ${tmp}/analyzer_dump
fi

echo $date > ${tmp}/analyzer_dump/date
echo $total_access_num  > ${tmp}/analyzer_dump/pv
echo $uniq_access_num  > ${tmp}/analyzer_dump/uniq_access
cat ${tmp}/access_detail  > ${tmp}/analyzer_dump/detail
echo $attack_num  > ${tmp}/analyzer_dump/attack

# push data to databox
$ROOT/bin/DATA_shell databox:web_analyzer authkey:$authkey \
action:set id:new keys:all input_dir:${tmp}/analyzer_dump

exit 0
