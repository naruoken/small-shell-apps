#!/bin/bash

#########################################################
# :usage
# apache2_log_analyer $domain_name
#########################################################

# load param
domain=$1
log="/var/log/apache2/access.log.1"
SCRIPT_DIR=`dirname $0`
. ${SCRIPT_DIR}/../../global.conf
tmp="${SCRIPT_DIR}/tmp"
date=`date +%Y-%m-%d --date '1 day ago'`

# load authkey
. ${SCRIPT_DIR}/.authkey

if [ ! "$domain" ];then
  echo "error: domain is null"
  exit 1
fi

# command check
which whois >/dev/null 2>&1
if [  ! $? -eq 0 ];then
  echo "error: please insetall whois command"
  exit 1
fi

# analytics
total_access_num=`cat $log | grep $domain | wc -l | tr -d " "`
cat $log | grep $domain | $AWK '{print $1}' | sort | uniq > ${tmp}/uniq_access.tmp
uniq_access_num=`cat ${tmp}/uniq_access.tmp | wc -l | tr -d " "`

echo "#guess country code" >  ${tmp}/whois_dump
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

# push data to databox
$ROOT/bin/DATA_shell databox:apache2_analyzer authkey:$authkey \
action:set id:new keys:all input_dir:${tmp}/analyzer_dump

exit 0
