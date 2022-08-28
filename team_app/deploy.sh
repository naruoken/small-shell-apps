#!/bin/bash

WHOAMI=`whoami`
if [ ! "$WHOAMI" = "root" ];then
  echo "error: user must be root"
  exit 1
fi

echo -n "small-shell root (/usr/local/small-shell): "
read ROOT

echo $ROOT

if [ ! "$ROOT" ];then
  ROOT=/usr/local/small-shell
fi

if [ ! -d $ROOT ];then
  echo "error: there is no directory $ROOT"
  exit 1
fi


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
  cp ./cgi-bin/$src $cgidir/$src
  chown $cgiusr:$cgiusr $cgidir/$src
  chmod 700 $cgidir/$src
done

for src in `ls ./bin | xargs basename -a`
do
  cp ./bin/$src $cgidir/../bin/$src
  chown $cgiusr:$cgiusr $cgidir/../bin/$src
  chmod 755 $cgidir/../bin/$src
done

rand=$RANDOM
for src in `ls ./descriptor | grep -v common_parts | xargs basename -a`
do
  cat ./descriptor/$src | $SED "s/%%rand/$rand/g" > $cgidir/../descriptor/$src
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
cat ./cgi-bin/inquiry | $SED "s/%%authkey/$authkey/g" >  $cgidir/inquiry

# create databox
for src in `ls ./def | xargs basename -a`
do
  $ROOT/util/scripts/bat_gen.sh ./def/$src 
done

clear
echo "-------------------------------------------------------------------------"
echo "Team APP deployment has been done, please create APP user."
echo "sudo $ROOT/adm/ops add.usr:\$user app:team"
echo "-------------------------------------------------------------------------"

exit 0
