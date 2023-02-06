#!/bin/bash

# global.conf load
SCRIPT_DIR=`dirname $0`
. ${SCRIPT_DIR}/../../global.conf

WHOAMI=`whoami`
if [ ! "$WHOAMI" = "root" ];then
  echo "error: user must be root"
  exit 1
fi

# load web/base
. $ROOT/web/base

# renew cert
certbot renew --dry-run

if [ $? -eq 0 ];then
  # deploy certificate & key
  cat /etc/letsencrypt/live/${server}/fullchain.pem > ${www}/app/cert.pem
  cat /etc/letsencrypt/live/${server}/privkey.pem > ${www}/app/privatekey.pem
  # restart web
  systemctl stop small-shell
  systemctl start small-shell
else
  echo "error: something must be wrong"
  exit 1
fi

exit 0
