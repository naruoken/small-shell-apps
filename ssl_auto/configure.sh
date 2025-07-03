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

# Mac check
cat /etc/passwd | grep small-shell > /dev/null 2>&1
if [ ! $? -eq 0 ];then
  mac_chk=`dscl . list /Users 2>/dev/null | grep small-shell 2>/dev/null`
  if [ "$mac_chk" ];then
    echo "error: this tool is not designed for Mac"
    exit 1
  fi
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
  echo "error: please setup Base APP first by using \"$ROOT/adm/gen -app\" command"
  exit 1
fi

# check default srv
if [ ! "$srv_type" = "default" ];then
  echo "error: you need to setup Base APP by using small-shell default WEB srv, please execute \"sudo $ROOT/adm/gen -app\" again"
  exit 1
fi

# check process
chk_srv=`ps -ef | grep index.js | grep -v "grep index.js"`
if [ ! "$chk_srv" ];then
  echo "error: please start small-shell WEB server first by executing \"sudo systemctl start small-shell\""
  exit 1
fi

if [ "$cluster_server" ];then
  which nginx >/dev/null 2>&1
  if [ ! $? -eq 0 ];then
    echo "error: you need to install nginx with no configuration"
    exit 1
  fi
fi

# update nginx configuration
if [ "$cluster_server" ];then
  if [ ! "$master" ];then
    # for master
    cat <<EOF > .default.conf
# Default server configuration for small-shell

server {
	listen 80;
	server_name _;
        return       444;
}

server {
        listen 80;
        server_name ${server};
        location / {
           proxy_pass    http://localhost:8080/;
           proxy_set_header Host \$host;
           proxy_set_header X-Real-IP \$remote_addr;
           proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
           client_max_body_size 4G;
        }
}

server {
        listen 80;
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
    cat <<EOF > .default.conf
# Default server configuration for small-shell

server {
	listen 80;
	server_name _;
        return       444;
}

server {
        listen 80;
        server_name ${server};
        location / {
           proxy_pass    http://localhost:8080/;
           proxy_set_header Host \$host;
           proxy_set_header X-Real-IP \$remote_addr;
           proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        }
}

server {
        listen 80;
        server_name ${cluster_server};
        location / {
           proxy_pass    http://${master}/;
           proxy_set_header Host \$host;
           proxy_set_header X-Real-IP \$remote_addr;
           proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        }
}
EOF
  fi
  # change node.js APP port
  node_version=`node --version | $SED "s/v//g" | $AWK -F "." '{print $1}'`
  if [ "$node_version" -ge 16 ];then
    cat $ROOT/web/src/app/index.js | $SED "s/%%protocol/http/g" | $SED "s/%%port/8080/g" \
    | $SED "s#%%sed#$SED#g" | $SED "s/%%cluster/cluster.isPrimary/g" > ${www}/app/index.js
  else
    cat $ROOT/web/src/app/index.js | $SED "s/%%protocol/http/g" | $SED "s/%%port/8080/g" \
    | $SED "s#%%sed#$SED#g" | $SED "s/%%cluster/cluster.isMaster/g" > ${www}/app/index.js
  fi
  systemctl restart small-shell

  # start nginx
  cp .default.conf /etc/nginx/sites-available/default
  systemctl restart nginx
  if [ ! $? -eq 0 ];then
    echo "error: failed to start reverse proxy, something must be wrong"
    if [ "$node_version" -ge 16 ];then
      cat $ROOT/web/src/app/index.js | $SED "s/%%protocol/http/g" | $SED "s/%%port/80/g" \
      | $SED "s#%%sed#$SED#g" | $SED "s/%%cluster/cluster.isPrimary/g" > ${www}/app/index.js
    else
      cat $ROOT/web/src/app/index.js | $SED "s/%%protocol/http/g" | $SED "s/%%port/80/g" \
      | $SED "s#%%sed#$SED#g" | $SED "s/%%cluster/cluster.isMaster/g" > ${www}/app/index.js
    fi
    systemctl restart small-shell
    exit 1 
  fi
  # create flg file
  echo "cluster=yes" > ./.configure
  echo "ROOT=\"$ROOT\"" >> ./.configure
  chmod 755 ./.configure
  echo "--------------------------------------------------------------------------------------"
  echo "reverse proxy setting has been done, please execute ./deploy.sh for cert deployment"
  echo "--------------------------------------------------------------------------------------"

else

  # for standalone host, not need to use nginx
  # create flg file
  echo "cluster=no" > ./.configure
  echo "ROOT=\"$ROOT\"" >> ./.configure
  chmod 755 ./.configure
  echo "--------------------------------------------------------------------------------------"
  echo "configuration has been done, please execute ./deploy.sh for cert deployment"
  echo "--------------------------------------------------------------------------------------"
fi

exit 0
