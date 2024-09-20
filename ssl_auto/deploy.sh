#!/bin/bash

WHOAMI=`whoami`
if [ ! "$WHOAMI" = "root" ];then
  echo "error: user must be root"
  exit 1
fi

if [ ! -d ./job ];then
  echo "please execute this script at `dirname $0`"
  exit 1
fi

ROOT=`cat .path 2>/dev/null `
if [ ! $ROOT ];then
  echo "error: you need to execute configure beforehand, please execute ./configure.sh"
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
  echo "error: you need to launch small-shell default web server first, http mode should be ok so far"
  exit 1
fi

# check pre configured or not 
if [ "$cluster_server" ];then
  chk_config=`grep $cluster_server /etc/nginx/sites-available/default`
  if [ ! "$chk_config" ];then
    echo "error: you need to execute configure beforehand, please execute ./configure.sh"
    exit 1
  fi
  for replica in $replica_hosts
  do
    chk_config=`sudo -u small-shell ssh $replica grep $cluster_server /etc/nginx/sites-available/default`
    if [ ! "$chk_config" ];then
      echo "error: you need to execute configure beforehand, please execute ./configure.sh on $replica"
      exit 1
    fi
  done
  chk_https=`grep 443 /etc/nginx/sites-available/default`
  if [ "$chk_https" ];then
    echo "error: please execute ./configure.sh again"
    exit 1
  fi
  chk_nginx=`ps -ef | grep nginx | grep -v grep`
  if [ ! "$chk_nginx" ];then
    echo "error: please execute ./configure.sh again"
    exit 1
  fi
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

  which nginx >/dev/null 2>&1
  if [ ! $? -eq 0 ];then
    echo "error: you need to install nginx with no configuration"
    exit 1
  fi

  if [ ! "$cluster_server" ];then
    certbot certonly --webroot -w ${www}/html -d $server
  else
    certbot certonly --webroot -w ${www}/html -d $server
    certbot certonly --webroot -w ${www}/html -d $cluster_server
  fi

  if [ ! -d ${www}/app/reverse_proxy ];then
    mkdir -p ${www}/app/reverse_proxy
  fi

  if [ "$cluster_server" ];then
    if [ -d /etc/letsencrypt/live/${cluster_server} ];then
      cp /etc/letsencrypt/live/${cluster_server}/fullchain.pem ${www}/app/reverse_proxy/${cluster_server}_cert.pem
      cp /etc/letsencrypt/live/${cluster_server}/privkey.pem ${www}/app/reverse_proxy/${cluster_server}_privatekey.pem
    else
      echo "error: something must be wrong"
      exit 1
    fi
   fi

   if [ -d /etc/letsencrypt/live/${server} ];then
     cp /etc/letsencrypt/live/${server}/fullchain.pem ${www}/app/reverse_proxy/${server}_cert.pem
     cp /etc/letsencrypt/live/${server}/privkey.pem ${www}/app/reverse_proxy/${server}_privatekey.pem
   else
     echo "error: something must be wrong"
     exit 1
   fi

    chown -R small-shell:small-shell ${www}/app/reverse_proxy
    chmod 600 ${www}/app/reverse_proxy/*_privatekey.pem

else
  # if there is master information in web/base, just get certificate from master
  if [ ! -d ${www}/app/reverse_proxy ];then
    mkdir -p ${www}/app/reverse_proxy
    chown -R small-shell:small-shell ${www}/app/reverse_proxy
  fi

  sudo -u small-shell ssh $master ls ${www}/app/reverse_proxy/${cluster_server}_cert.pem
  if [ ! $? -eq 0 ];then
    echo "error: there is no certification on master server, please execute ./deploy.sh on $master first"
    exit 1
  fi
   
  sudo -u small-shell scp -i /home/small-shell/.ssh/id_rsa small-shell@${master}:${www}/app/reverse_proxy/${cluster_server}_*pem ${www}/app/reverse_proxy/
  if [ ! $? -eq 0 ];then
    echo "error: something must be wrong"
    exit 1
  fi
fi

# upgrade web/base
cat $ROOT/web/base | $SED "s/\"http\"/\"https\"/g" | $SED "s/http:/https:/g" | grep -v "reverse_proxy=" > $ROOT/web/.base
echo "reverse_proxy=\"yes\"" >> $ROOT/web/.base
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

# update nginx config
cat /etc/nginx/sites-available/default > .default.conf
cat /etc/nginx/sites-available/default > .default.conf.org
if [ "$cluster_server" -a ! "$master" ];then
  # for master
  cat <<EOF >> .default.conf

server {
        listen 443;
        ssl on;
        ssl_certificate ${www}/app/reverse_proxy/${cluster_server}_cert.pem;
        ssl_certificate_key ${www}/app/reverse_proxy/${cluster_server}_privatekey.pem;
        server_name _;
        return       444;
}

server {
	listen 443;
        ssl on;
        ssl_certificate ${www}/app/reverse_proxy/${server}_cert.pem;
        ssl_certificate_key ${www}/app/reverse_proxy/${server}_privatekey.pem;

	server_name ${server};
	location / {
           proxy_pass    http://localhost:8080/; 
           proxy_set_header Host \$host;
           proxy_set_header X-Real-IP \$remote_addr;
           proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
	}
}

server {
        listen 443;
        ssl on;
        ssl_certificate ${www}/app/reverse_proxy/${cluster_server}_cert.pem;
        ssl_certificate_key ${www}/app/reverse_proxy/${cluster_server}_privatekey.pem;

        server_name ${cluster_server};
        location / {
           proxy_pass    http://localhost:8080/; 
           proxy_set_header Host \$host;
           proxy_set_header X-Real-IP \$remote_addr;
           proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        }
}
EOF

elif [ "$master" ];then
  # for replica
  cat <<EOF >> .default.conf

server {
        listen 443;
        ssl on;
        ssl_certificate ${www}/app/reverse_proxy/${cluster_server}_cert.pem;
        ssl_certificate_key ${www}/app/reverse_proxy/${cluster_server}_privatekey.pem;
        server_name _;
        return       444;
}

server {
	listen 443;
        ssl on;
        ssl_certificate ${www}/app/reverse_proxy/${cluster_server}_cert.pem;
        ssl_certificate_key ${www}/app/reverse_proxy/${cluster_server}_privatekey.pem;

	server_name ${cluster_server};
	location / {
           proxy_pass    http://localhost:8080/; 
           proxy_set_header Host \$host;
           proxy_set_header X-Real-IP \$remote_addr;
           proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
	}
}
EOF
else
  # for standalone host
  cat <<EOF >> .default.conf

server {
        listen 443;
        ssl on;
        ssl_certificate ${www}/app/reverse_proxy/${server}_cert.pem;
        ssl_certificate_key ${www}/app/reverse_proxy/${server}_privatekey.pem;
        server_name _;
        return       444;
}

server {
	listen 443;
        ssl on;
        ssl_certificate ${www}/app/reverse_proxy/${server}_cert.pem;
        ssl_certificate_key ${www}/app/reverse_proxy/${server}_privatekey.pem;

	server_name ${server};
	location / {
           proxy_pass    http://localhost:8080/; 
           proxy_set_header Host \$host;
           proxy_set_header X-Real-IP \$remote_addr;
           proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
	}
}
EOF
fi

# restart nginx
cp .default.conf /etc/nginx/sites-available/default
systemctl restart nginx
if [ ! $? -eq 0 ];then
  echo "error: failed to upgrade reverse proxy (nginx), something must be wrong"
  cp .default.conf.org /etc/nginx/sites-available/default
  systemctl restart nginx
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
#clear
echo "Successfully depoyed, your small-shell web server is already upgraded to https with reverse proxy"
echo "Please add following line to sudoers by visudo command"
echo "---------------------------------------------------------------------------------------------------"
echo "small-shell   ALL=(ALL:ALL)    NOPASSWD: /usr/local/small-shell/util/scripts/ssl_auto.sh"
echo "---------------------------------------------------------------------------------------------------"

if [ "$cluster_server" -a ! "$master" ];then
  echo "Also you need to execute ./deploy.sh on $replica_hosts as well"
fi

exit 0
