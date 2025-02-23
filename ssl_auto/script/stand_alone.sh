#!/bin/bash

WHOAMI=`whoami`
if [ ! "$WHOAMI" = "root" ];then
  echo "error: user must be root"
  exit 1
fi

# load configure
SCRIPT_DIR=`dirname $0`
. ${SCRIPT_DIR}/../.configure

if [ ! "$ROOT" ];then
  echo "error: failed to load .configure"
  exit 1
fi

# load global conf and base
. $ROOT/global.conf
. $ROOT/web/base

if [ ! "$www" ];then
  echo "error: please launch Base APP first by using \"$ROOT/adm/gen -app\" command"
  exit 1
fi

# check process
chk_srv=`ps -ef | grep index.js | grep -v "grep index.js"`
if [ ! "$chk_srv" ];then
  echo "error: please launch small-shell default web server first, http mode should be ok so far"
  exit 1
fi

# check certbot command
which certbot >/dev/null 2>&1

if [ ! $? -eq 0 ];then
  echo "error: plases install certbot first"
  exit 1 
fi

# create certificate
certbot certonly --webroot -w /var/www/html -d $server

if [ $? -eq 0 ];then

  # deploy certificate & key
  if [ -d /etc/letsencrypt/live/${server} ];then
    cp /etc/letsencrypt/live/${server}/fullchain.pem ${www}/app/cert.pem
    cp /etc/letsencrypt/live/${server}/privkey.pem ${www}/app/privatekey.pem
    chown small-shell:small-shell ${www}/app/cert.pem
    chown small-shell:small-shell ${www}/app/privatekey.pem
    chmod 600 ${www}/app/privatekey.pem
  else
    echo "error: something must be wrong"
    exit 1
  fi

  node_version=`node --version | $SED "s/v//g" | $AWK -F "." '{print $1}'`
  if [ "$node_version" -ge 16 ];then
    cat $ROOT/web/src/app/index.js | $SED "s/%%protocol/https/g" | $SED "s/%%port/443/g" \
    | $SED "s#%%sed#$SED#g" | $SED "s#// https ##g" | $SED "s#/\* forward option start##g" \
    | $SED "s#option end \*/##g" | $SED "s/%%cluster/cluster.isPrimary/g" > ${www}/app/index.js
  else
  # generate index.js for lower version of v16        
    cat $ROOT/web/src/app/index.js | $SED "s/%%protocol/https/g" | $SED "s/%%port/443/g" \
    | $SED "s#%%sed#$SED#g" | $SED "s#// https ##g" | $SED "s#/\* forward option start##g" \
    | $SED "s#option end \*/##g" | $SED "s/%%cluster/cluster.isMaster/g" > ${www}/app/index.js
  fi

  # upgrade web/base
  cat $ROOT/web/base | $SED "s/http/https/g" > $ROOT/web/.base
  cat $ROOT/web/.base > $ROOT/web/base

  # update index
  grep -rl ${index_url} $www  > .list.tmp
  while read line
  do
    cat $line | $SED "s/http/https/g" > .index.new
    cat .index.new > $line
  done < .list.tmp

  # restart web
  systemctl stop small-shell
  systemctl start small-shell

else
  echo "error: something must be wrong"
  exit 1
fi

# job copy and enable 
cat ./script/ssl_auto.sh | $SED "s#%%ROOT#$ROOT#g" > $ROOT/util/scripts/ssl_auto.sh
cat ./job/ssl_auto.def | $SED "s#%%ROOT#$ROOT#g" > $ROOT/util/e-cron/def/ssl_auto.def
cat ./job/.ssl_auto.dump |  $SED "s#%%ROOT#$ROOT#g" > $ROOT/util/e-cron/def/.ssl_auto.dump

chown small-shell:small-shell $ROOT/util/scripts/ssl_auto.sh
chown small-shell:small-shell $ROOT/util/e-cron/def/ssl_auto.def
chown small-shell:small-shell $ROOT/util/e-cron/def/.ssl_auto.dump
chmod 755 $ROOT/util/scripts/ssl_auto.sh
chmod 755 $ROOT/util/e-cron/def/ssl_auto.def
sudo -u small-shell $ROOT/bin/e-cron enable.ssl_auto

# Note
sleep 2
clear
echo "---------------------------------------------------------------------------------"
echo "successfully depoyed, your small-shell web server is already upgraded to https"
echo "---------------------------------------------------------------------------------"
echo "please add following line to sudoers by visudo command"
echo "small-shell   ALL=(ALL:ALL)    NOPASSWD: /usr/local/small-shell/util/scripts/ssl_auto.sh"

exit 0
