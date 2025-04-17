#!/bin/bash

WHOAMI=`whoami`
if [ ! "$WHOAMI" = "root" ];then
  echo "error: user must be root"
  exit 1
fi

if [ ! -d ./def ];then
  echo "please execute this script at `dirname $0`"
  exit 1
fi

echo -n "small-shell root (/usr/local/small-shell): "
read ROOT

if [ ! "$ROOT" ];then
  ROOT=/usr/local/small-shell
fi

if [ ! -d $ROOT ];then
  echo "error: there is no directory $ROOT"
  exit 1
fi

echo -n "Do you want to enable IP whitelisting for this APP ? (yes | no): "
read IP_whitelisting
while [ ! "$IP_whitelisting" = "yes" -a ! "$IP_whitelisting" = "no" ]
do 
  echo "please input yes or no"
  echo -n "Do you want to enable IP whitelisting ? (yes | no): "
  read IP_whitelisting
done

# loal global conf
. $ROOT/global.conf

# load web base
. $ROOT/web/base

if [ ! "$cgidir" ];then
  echo "error: please gen base app first #${root}/adm/gen -app"
  exit 1
fi

# deploy script to production env
for src in `ls ./cgi-bin | xargs basename -a`
do
  cat ./cgi-bin/$src | $SED "s#%%www#${www}#g" | $SED "s#%%authkey#$api_authkey#g" \
  | $SED "s/%%IP_whitelisting/$IP_whitelisting/g" > $cgidir/$src
  chown $cgiusr:$cgiusr $cgidir/$src
  chmod 700 $cgidir/$src
done

for src in `ls ./bin | xargs basename -a`
do
  cat ./bin/$src | $SED "s#%%www#${www}#g" > $www/bin/$src
  chown $cgiusr:$cgiusr $www/bin/$src
  chmod 755 $www/bin/$src
done

if [ -f $cgidir/../descriptor/.team.rand ];then
  . $cgidir/../descriptor/.team.rand
else
  rand=$RANDOM
  echo "rand=$rand" > $cgidir/../descriptor/.team.rand
  chmod 755 $cgidir/../descriptor/.team.rand
fi

for src in `ls ./descriptor | grep -v common_parts | xargs basename -a`
do
  cat ./descriptor/$src | $SED "s#%%rand#$rand#g" | $SED "s#%%base_url/#$base_url#g" > $cgidir/../descriptor/$src
  chmod 755 $cgidir/../descriptor/$src
done

for src in `ls ./descriptor/common_parts | xargs basename -a`
do
  cat ./descriptor/common_parts/$src | $SED "s/%%rand/$rand/g" > $cgidir/../descriptor/common_parts/$src
  chmod 755 $cgidir/../descriptor/common_parts/$src
done

# create authkey for inquiry form
app=inquiry
app_user_name=${app}.app
app_user_id=`echo "$app_user_name" | $SHASUM | $AWK '{print $1}'`

if [ ! -d $ROOT/users/${app}.${app_user_id} ];then
  mkdir $ROOT/users/${app}.${app_user_id}
fi
echo "$app_user_name" > $ROOT/users/${app}.${app_user_id}/user_name
echo "permission=rw" > $ROOT/users/${app}.${app_user_id}/.attr.tmp
cat $ROOT/users/${app}.${app_user_id}/.attr.tmp > $ROOT/users/${app}.${app_user_id}/attr
chown small-shell:small-shell $ROOT/users/${app}.${app_user_id}/attr

which openssl  >/dev/null 2>&1
if [ $? -eq 0 ];then
  hash_gen_key=`openssl rand -hex 20`
else
  hash_gen_key="${RANDOM}.${RANDOM}.${RANDOM}.${RANDOM}.${RANDOM}"
fi

hash=`echo "${app}:${app_user_name}:${hash_gen_key}" | $SHASUM | $AWK '{print $1}'`
echo "$hash" > $ROOT/users/${app}.${app_user_id}/hash
chown -R small-shell:small-shell $ROOT/users/${app}.${app_user_id}
chmod 700 $ROOT/users/${app}.${app_user_id}/hash
authkey=`echo "${app_user_name}:${hash_gen_key}" | $BASE64_ENC`

# update form APP
cat ./cgi-bin/inquiry | $SED "s#%%www#${www}#g" | $SED "s/%%authkey/$authkey/g" \
| $SED "s/%%IP_whitelisting/$IP_whitelisting/g" >  $cgidir/inquiry

# create databox
for src in `ls ./def | xargs basename -a`
do
  $ROOT/util/scripts/bat_gen.sh ./def/$src 
done

clear
echo "-----------------------------------------------------------------------------------"
echo "Team APP deployment has been done, please create APP user by following command."
echo "-----------------------------------------------------------------------------------"
echo "sudo $ROOT/adm/ops app:team add.usr:\$user"
echo ""
echo "Team APP URL: ${base_url}/team"
echo "Inquiry Form URL: ${base_url}/inquiry"
echo "-----------------------------------------------------------------------------------"

# create index.html
if [ ! -d $www/html/team ];then
  mkdir $www/html/team
fi
cat $ROOT/web/src/descriptor/redirect.html.def | $SED "s#%%APPURL#${base_url}auth.team#g" > $www/html/team/index.html
chmod 755 $www/html/team/index.html

if [ ! -d $www/html/inquiry ];then
  mkdir $www/html/inquiry
fi
cat $ROOT/web/src/descriptor/redirect.html.def | $SED "s#%%APPURL#${base_url}inquiry#g" > $www/html/inquiry/index.html
chmod 755 $www/html/inquiry/index.html

exit 0
