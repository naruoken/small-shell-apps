#!/bin/bash

WHOAMI=`whoami`
if [ ! "$WHOAMI" = "root" ];then
  echo "error: user must be root"
  exit 1
fi

echo -n "small-shell root (/usr/local/small-shell): "
read ROOT

if [ ! "$ROOT" ];then
  ROOT=/usr/local/small-shell
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

echo -n "Target domain: "
read domain
while [ ! "$domain" ]
do
  echo -n "please input Taprget domain name: "
  read domain
done

# check certbot command
which certbot >/dev/null 2>&1

if [ ! $? -eq 0 ];then
  echo "error: plases install certbot beorehand by using follogin command"
  echo "sudo snap install core; sudo snap refresh core; sudo snap install --classic certbot ; sudo ln -s /snap/bin/certbot /usr/bin/certbot"
  exit 1 
fi

# create certificate
certbot certonly --webroot -w /var/www/html -d $domain

if [ $? -eq 0 ];then

  # deploy certificate & key
  if [ -d /etc/letsencrypt/live/${domain} ];then
    cp /etc/letsencrypt/live/${domain}/fullchain.pem ${www}/app/cert.pem
    cp /etc/letsencrypt/live/${domain}/privkey.pem ${www}/app/privatekey.pem
  else
    echo "error: something must be wrong"
    exit 1
  fi

  # upgrade web srv from http to https
  cat $ROOT/web/src/app/index.js | $SED "s/%%protocol/https/g" | $SED "s/%%port/443/g" \
  | $SED "s#/\* forward option start##g" | $SED "s#option end \*/##g" \
  | $SED "s#%%sed#$SED#g" | $SED "s#// https ##g" > ${www}/app/index.js

  # upgrade web/base
  cat $ROOT/web/base | $SED "s/http/https/g" > $ROOT/web/.base
  echo "domain=${domain}" >> $ROOT/web/.base
  cat $ROOT/web/.base > $ROOT/web/base

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
