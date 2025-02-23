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
if [ ! "$cluster_server" ];then
  certbot renew
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
else
  if [ ! "$master" ];then
    # if there is no entry of master host, execute certbot
    certbot renew
    if [ $? -eq 0 ];then
      # deploy certificate & key
      if [ "$cluster_server" ];then
        cat /etc/letsencrypt/live/${cluster_server}/fullchain.pem > ${www}/app/reverse_proxy/${cluster_server}_cert.pem
        cat /etc/letsencrypt/live/${cluster_server}/privkey.pem > ${www}/app/reverse_proxy/${cluster_server}_privatekey.pem
      fi
      cat /etc/letsencrypt/live/${server}/fullchain.pem > ${www}/app/reverse_proxy/${server}_cert.pem
      cat /etc/letsencrypt/live/${server}/privkey.pem > ${www}/app/reverse_proxy/${server}_privatekey.pem
    else
      echo "error: something must be wrong"
      exit 1
    fi
  else
    #sleep 60
    sudo -u small-shell scp -i /home/small-shell/.ssh/id_rsa small-shell@${master}:${www}/app/reverse_proxy/${cluster_server}_*pem ${www}/app/reverse_proxy/
  fi
  # restart web
  systemctl stop nginx
  systemctl start nginx
fi

exit 0
