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

# load param
for param in `echo $@`
do
  if [[ $param == domain:* ]];then
    domain=`echo $param | $AWK -F":" '{print $2}'`
    chk_domain=`echo $domain | $SED "s/\*.//g"`
    if [ ! "$chk_domain" ];then
      echo "error: domain is null"
      exit 1
    fi
  fi
done

if [ ! "$www" ];then
  echo "error: please launch Base APP first by using \"$ROOT/adm/gen -app\" command"
  exit 1
fi

# check process
chk_srv=`ps -ef | grep index.js | grep -v "grep index.js"`
if [ ! "$chk_srv" ];then
  echo "error: you need to launch small-shell default web server first, http mode should be ok so far"
  exit 1
fi

# create certificate
if [ ! "$master" ];then
  # if there is no master information in web/base, it means this host is master or there is no clustering host
  # check certbot command
  which certbot >/dev/null 2>&1

  if [ ! $? -eq 0 ];then
    echo "error: you need to install certbot beforehand by using following command"
    echo "sudo snap install core; sudo snap refresh core; sudo snap install --classic certbot ; sudo ln -s /snap/bin/certbot /usr/bin/certbot"
    exit 1
  fi

  if [ ! "$domain" ];then
    certbot certonly --webroot -w ${www}/html -d $server
  else
    remove_wild_card=`echo "$domain" | $SED "s/\*.//g"`
    certbot certonly --manual -d $domain -d $remove_wild_card --preferred-challenges dns
    domain=$remove_wild_card
  fi

else
  # if there is master information in web/base, just get certificate from master
  if [ "$domain" ];then
    remove_wild_card=`echo "$domain" | $SED "s/\*.//g"`
    domain=$remove_wild_card
  fi

  if [ ! -d /etc/letsencrypt/live ];then
    mkdir -p /etc/letsencrypt/live
  fi

  chown small-shell:small-shell /etc/letsencrypt/live
  sudo -u small-shell scp -i /home/small-shell/.ssh/id_rsa small-shell@${master}:${www}/app/*pem ${www}/app/
fi

if [ $? -eq 0 ];then

  # deploy certificate & key
  if [ ! "$master" ];then
    if [ "$domain" ];then
      if [ -d /etc/letsencrypt/live/${domain} ];then
        cp /etc/letsencrypt/live/${domain}/fullchain.pem ${www}/app/cert.pem
        cp /etc/letsencrypt/live/${domain}/privkey.pem ${www}/app/privatekey.pem
        chown small-shell:small-shell ${www}/app/cert.pem
        chown small-shell:small-shell ${www}/app/privatekey.pem
        chmod 600 ${www}/app/privatekey.pem
      else
        echo "error: something must be wrong"
        exit 1
      fi
    else
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
    fi
  fi

  # upgrade web srv from http to https
  node_version=`node --version | $SED "s/v//g" | $AWK -F "." '{print $1}'`
  if [ "$node_version" -ge 16 ];then
    cat $ROOT/web/src/app/index.js | $SED "s/%%protocol/https/g" | $SED "s/%%port/443/g" \
    | $SED "s#%%sed#$SED#g" | $SED "s#// https ##g" | $SED "s#/\* forward option start##g" \
    | $SED "s#option end \*/##g" | $SED "s/%%cluster/cluster.isPrimary/g" > ${www}/app/index.js
  else
    cat $ROOT/web/src/app/index.js | $SED "s/%%protocol/https/g" | $SED "s/%%port/443/g" \
    | $SED "s#%%sed#$SED#g" | $SED "s#// https ##g" | $SED "s#/\* forward option start##g" \
    | $SED "s#option end \*/##g" | $SED "s/%%cluster/cluster.isMaster/g" > ${www}/app/index.js
  fi

  # upgrade web/base
  if [ "$domain" ];then
    cat $ROOT/web/base | $SED "s/\"http\"/\"https\"/g" | $SED "s/http:/https:/g" | grep -v ssl_domain= > $ROOT/web/.base
    echo "ssl_domain=\"$domain\"" >> $ROOT/web/.base
  else
    cat $ROOT/web/base | $SED "s/\"http\"/\"https\"/g" | $SED "s/http:/https:/g" > $ROOT/web/.base
  fi
  cat $ROOT/web/.base > $ROOT/web/base

  # update descriptors
  new_index_url=`echo $index_url | $SED "s/http:/https:/g"`
  grep -rl ${index_url} $www  > .list.tmp
  while read line
  do
    cat $line | $SED "s#${index_url}#${new_index_url}#g" > .index.new
    cat .index.new > $line
  done < .list.tmp

  if [ "$cluster_base_url" ];then
    new_cluster_base_url=`echo $cluster_base_url | $SED "s/http:/https:/g"`
    grep -rl ${cluster_base_url} $www  > .list.tmp
    while read line
    do
      cat $line | $SED "s#${cluster_base_url}#${new_cluster_base_url}#g" > .index.new
      cat .index.new > $line
    done < .list.tmp

    # update menu
    . $ROOT/util/scripts/.authkey
    permission=`$ROOT/bin/meta get.attr:sys`
    if [ "$permission" = "ro" ];then
      $ROOT/adm/ops set.attr:sys{rw} > /dev/null 2>&1
    fi

    if [ "$replica_hosts" ];then
      tmp_dir=/var/tmp/ssl_auto
      mkdir $tmp_dir
      for target in `ls ${cgidir} | grep -v base | grep -v api | grep -v e-cron | xargs basename -a`
      do
        app=$target
        type3_chk=`grep "# controller for Scratch APP" ${cgidir}/${app}`
        if [ "$type3_chk" ];then
          if [ ! -d ${tmp_dir}/${app} ];then
            mkdir ${tmp_dir}/${app}
          fi
          # update UI.md.def
          id=`sudo -u small-shell $ROOT/bin/DATA_shell authkey:${authkey} databox:${app}.UI.md.def action:get command:head_-1 format:none | awk -F "," '{print $1}'`
          sudo -u small-shell $ROOT/bin/DATA_shell authkey:$authkey databox:${app}.UI.md.def action:get id:${id} key:righth format:none \
          | $SED "s#${cluster_base_url}#${new_cluster_base_url}#g" | $SED "s/_%%enter_/\n/g" | $SED "s/righth://g"  > ${tmp_dir}/${app}/righth
          sudo -u small-shell $ROOT/bin/DATA_shell authkey:${authkey} databox:${app}.UI.md.def action:set id:${id} key:righth input_dir:${tmp_dir}/${app}

          sudo -u small-shell $ROOT/bin/DATA_shell authkey:$authkey databox:${app}.UI.md.def action:get id:${id} key:lefth format:none \
          | $SED "s#${cluster_base_url}#${new_cluster_base_url}#g" | $SED "s/_%%enter_/\n/g" | $SED "s/lefth://g"  > ${tmp_dir}/${app}/lefth
          sudo -u small-shell $ROOT/bin/DATA_shell authkey:${authkey} databox:${app}.UI.md.def action:set id:${id} key:lefth input_dir:${tmp_dir}/${app}
        fi
      done
      rm -rf $tmp_dir
      if [ "$permission" = "ro" ];then
        $ROOT/adm/ops set.attr:sys{ro} > /dev/null 2>&1
      fi
    fi
  fi

  if [ "$master" ];then 
    grep -rl "http://${master}" $www  > .list.tmp
    while read line
    do
      cat $line | $SED "s#http://${master}#https://${master}#g" > .index.new
      cat .index.new > $line
    done < .list.tmp
  fi

  # restart web
  systemctl stop small-shell
  systemctl start small-shell

else
  echo "error: something must be wrong"
  exit 1
fi

# job copy and enable 
if [ ! "$master" ];then
  cat ./script/ssl_auto.sh | $SED "s#%%ROOT#$ROOT#g" > $ROOT/util/scripts/ssl_auto.sh
  cat ./job/ssl_auto.def | $SED "s#%%ROOT#$ROOT#g" > $ROOT/util/e-cron/def/ssl_auto.def
  cat ./job/.ssl_auto.dump |  $SED "s#%%ROOT#$ROOT#g" > $ROOT/util/e-cron/def/.ssl_auto.dump
else
  # if there is master host information in web/base, change execution date to next day just in case.
  cat ./script/ssl_auto.sh | $SED "s#%%ROOT#$ROOT#g" > $ROOT/util/scripts/ssl_auto.sh
  cat ./job/ssl_auto.def | $SED "s#%%ROOT#$ROOT#g" | $SED "s/SCHEDULE:1 0 1/SCHEDULE:1 0 2/g" > $ROOT/util/e-cron/def/ssl_auto.def
  cat ./job/.ssl_auto.dump |  $SED "s#%%ROOT#$ROOT#g" | $SED "s/date: 1/date: 2/g" > $ROOT/util/e-cron/def/.ssl_auto.dump
fi

chown small-shell:small-shell $ROOT/util/scripts/ssl_auto.sh
chown small-shell:small-shell $ROOT/util/e-cron/def/ssl_auto.def
chown small-shell:small-shell $ROOT/util/e-cron/def/.ssl_auto.dump
chmod 755 $ROOT/util/scripts/ssl_auto.sh
chmod 755 $ROOT/util/e-cron/def/ssl_auto.def
sudo -u small-shell $ROOT/bin/e-cron enable.ssl_auto
sleep 2
clear
echo "---------------------------------------------------------------------------------"
echo "successfully depoyed, your small-shell web server is already upgraded to https"
echo "---------------------------------------------------------------------------------"
echo "please add following line to sudoers by visudo command"
echo "small-shell   ALL=(ALL:ALL)    NOPASSWD: /usr/local/small-shell/util/scripts/ssl_auto.sh"

exit 0
