#!/bin/bash

# load param
log="%%log_dir/srvdump.log.1"
SCRIPT_DIR=`dirname $0`
. ${SCRIPT_DIR}/../../global.conf
tmp="${SCRIPT_DIR}/tmp"
date=`date +%Y-%m-%d --date '1 day ago'`

# load authkey
. ${SCRIPT_DIR}/.authkey

# command check
which whois >/dev/null 2>&1
if [  ! $? -eq 0 ];then
  echo "error: please insetall whois command"
  exit 1
fi

# analytics
total_access_num=`cat $log | grep requested | grep -v "requested wrong page" | grep -v css | grep -v favicon.ico | wc -l | tr -d " "`
cat $log | grep requested | grep -v "requested wrong page" | grep -v css | grep -v favicon.ico | $AWK '{print $3}' | sort | uniq > ${tmp}/uniq_access.tmp
uniq_access_num=`cat ${tmp}/uniq_access.tmp | wc -l | tr -d " "`
attack_num=`cat ${log} | grep -v css | grep -v favicon.ico | grep "requested wrong page" | wc -l` 

echo "#guess country code of sccess access not include attack" >  ${tmp}/whois_dump
echo "target:$log"
echo "total_access:$total_access_num"
echo "uniq_access:$uniq_access_num"
echo "guess country code"
echo "-----------------------------------------------------------------------------"
while read client
do

  country_code=`whois $client | grep -i country | $AWK -F ":" '{print $2}' | sort | uniq \
  | $SED "s/ //g" | $SED -z "s/\n/,/g" | $SED "s/,$//g"`
  echo "$client:$country_code"
  echo "$client:$country_code" >> ${tmp}/whois_dump

done < ${tmp}/uniq_access.tmp

echo "-----------------------------------------------------------------------------"

# dump data

if [ ! -d ${tmp}/analyzer_dump ];then
  mkdir ${tmp}/analyzer_dump
fi

echo $date > ${tmp}/analyzer_dump/date
echo $total_access_num  > ${tmp}/analyzer_dump/pv
echo $uniq_access_num  > ${tmp}/analyzer_dump/uniq_access
cat ${tmp}/whois_dump  > ${tmp}/analyzer_dump/detail
echo $attack_num  > ${tmp}/analyzer_dump/attack

# push data to databox
$ROOT/bin/DATA_shell databox:web_analyzer authkey:$authkey \
action:set id:new keys:all input_dir:${tmp}/analyzer_dump

exit 0
