#!/bin/bash

WHOAMI=`whoami`
if [ ! "$WHOAMI" = "root" ];then
  echo "error: user must be root"
  exit 1
fi

echo -n "target domain or IP addr: "
read domain

if [ ! "$domain" ];then
  echo "error: please input domain or IP addr as target of analytics"
  exit 1
fi

echo -n "small-shell root (/usr/local/small-shell): "
read ROOT

if [ ! "$ROOT" ];then
  ROOT=/usr/local/small-shell
fi

# loal global conf
. $ROOT/global.conf

# log access permission check
echo -n "apache2 log dir (/var/log/apache2): "
read log_dir

if [ ! "$log_dir" ];then
  log_dir=/var/log/apache2
fi

if [ ! -d "$log_dir" ];then
  echo "error: there is no $log_dir"
  exit 1
fi

sudo -u small-shell ls /var/log/apache2/access.log >/dev/null 2>&1
if [ ! $? -eq 0 ];then
  echo "please add permission to the log dir, exit 1.."
  echo "command sugesstion is \"usermod -aG adm small-shell\""
  exit 1
fi

# change permission of sys user
chk_permission=`$ROOT/bin/meta get.attr:sys`
if [ ! "$chk_permission" = "rw" ];then
  echo -n "Is it OK to add read and write permission to sys user ? (yes | no): "
  read ANSWER
  if [ "$ANSWER" = "yes" ];then
    $ROOT/adm/ops set.attr:sys{rw}
  else
    echo "analyzer will sys user and it must have write permission to databox, exit 1..."
    exit 1
  fi
fi


# pyshell check
. $ROOT/util/pyshell/env
$PYTHON --version
if [ $? -eq 0 ];then
  echo "pyshell should be ready"
else
  echo "please install python libraries refering to https://small-shell.org/python_tour/"
  exit 1
fi

# whois check 
which whois >/dev/null 2>&1
if [ $? -eq 0 ];then
  echo "whois command is working"
else
  echo "you must install whois command, exit 1.."
  exit 1
fi

# db creation
$ROOT/util/scripts/bat_gen.sh ./db.def

# deploy analyzer to util/scripts
cat ./scripts/apache2_log_analyzer.sh  | $SED "s#%%log_dir#$log_dir#g" > $ROOT/util/scripts/apache2_log_analyzer.sh
chmod 755 $ROOT/util/scripts/apache2_log_analyzer.sh

# job copy and enable 
for job in pv_statistics.def log_analyzer.def uniq_statistics.def .pv_statistics.dump .log_analyzer.dump .uniq_statistics.dump
 
do
  cat ./jobs/$job | $SED "s/%%domain/$domain/g" > $ROOT/util/e-cron/def/$job
done

chmod 755 $ROOT/util/e-cron/def/log_analyzer.def
chmod 755 $ROOT/util/e-cron/def/pv_statistics.def
chmod 755 $ROOT/util/e-cron/def/uniq_statistics.def

sudo -u small-shell $ROOT/bin/e-cron enable.log_analyzer
sudo -u small-shell $ROOT/bin/e-cron enable.pv_statistics
sudo -u small-shell $ROOT/bin/e-cron enable.uniq_statistics

# Note
echo "--------------------------------------------------------------------------"
echo "apache2 log analyzer is successfully deployed"
echo "--------------------------------------------------------------------------"
echo "1. analyzer will analyze access.log.1 once it's made by anacron on 00:00"
echo "2. analytics will be done about 1 day ago log"
echo "3. you can check graph and data on Base APP"

exit 0
