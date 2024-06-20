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
if [ ! "$master" ];then
  # if there is no entry of master host, execute certbot
  certbot renew
  if [ $? -eq 0 ];then
    # deploy certificate & key
    if [ "$ssl_domain" ];then
      cat /etc/letsencrypt/live/${ssl_domain}/fullchain.pem > ${www}/app/cert.pem
      cat /etc/letsencrypt/live/${ssl_domain}/privkey.pem > ${www}/app/privatekey.pem
    else 
      cat /etc/letsencrypt/live/${server}/fullchain.pem > ${www}/app/cert.pem
      cat /etc/letsencrypt/live/${server}/privkey.pem > ${www}/app/privatekey.pem
    fi
  else
    echo "error: something must be wrong"
    exit 1
  fi
else
  #sleep 60
  sudo -u small-shell scp -i /home/small-shell/.ssh/id_rsa small-shell@${master}:${www}/app/*pem ${www}/app/
fi

# restart web
systemctl stop small-shell
systemctl start small-shell

exit 0
