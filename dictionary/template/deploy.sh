#!/bin/bash

tmp_dir=./tmp
WHOAMI=`whoami`
if [ ! "$WHOAMI" = "root" ];then
  echo "error: user must be root"
  exit 1
fi

if [ ! -f ./keywords ];then
  echo "please execute this script at `dirname $0`"
  exit 1
fi

echo -n "small-shell root (/usr/local/small-shell): "
read ROOT

if [ ! "$ROOT" ];then
  ROOT=/usr/local/small-shell
fi

# loal global conf
. $ROOT/global.conf

# load web base
. $ROOT/web/base

if [ ! $SED ];then
  echo "please execute $ROOT/adm/gen first"
  exit 1
fi

cat ./keywords | grep -v "^#" > ${tmp_dir}/.dictionary
# update web/src
while read line
do
  org="`echo $line | $AWK -F"{%%%%%%}" '{print $1}'`"
  new="`echo $line | $AWK -F"{%%%%%%}" '{print $2}'`"

  for dir in def bin cgi-bin
  do
    grep -rl "${org}" $ROOT/web/src/$dir > .list.tmp
    while read target
    do
      cat $target | $SED "s#${org}#${new}#g" > .target.new
      cat .target.new > $target
    done < .list.tmp
  done
done <  ${tmp_dir}/.dictionary

# update www
while read line
do
  org="`echo $line | $AWK -F"{%%%%%%}" '{print $1}'`"
  new="`echo $line | $AWK -F"{%%%%%%}" '{print $2}'`"

  for dir in def bin cgi-bin
  do
    grep -rl "${org}" $www/$dir > .list.tmp
    while read target
    do
      cat $target | $SED "s#${org}#${new}#g" > .target.new
      cat .target.new > $target
    done < .list.tmp
  done
done <  ${tmp_dir}/.dictionary 

# update menu for Scratch APP
portal=`grep "ScratchAPP:APP Portal" ./keywords | $SED "s/ScratchAPP:APP Portal{%%%%%%}//g"`
table=`grep "ScratchAPP:Table" ./keywords | $SED "s/ScratchAPP:Table{%%%%%%}//g"`
logout=`grep "ScratchAPP:Log Out" ./keywords | $SED "s/ScratchAPP:Log Out{%%%%%%}//g"`
. $ROOT/util/scripts/.authkey
permission=`$ROOT/bin/meta get.attr:sys`
if [ "$permission" = "ro" ];then
  $ROOT/adm/ops set.attr:sys{rw} > /dev/null 2>&1
fi

# update body and tmp/gen
if [ -f ./tmplt.UI.md.def/body ];then
  cat ./tmplt.UI.md.def/body > $ROOT/tmp/gen/.tmplt.UI.md.def/body
fi
if [ "$portal" -a "$table" ];then
  for target in `ls $ROOT/tmp/gen/.tmplt.UI.md.def | xargs basename -a`
  do
      cat $ROOT/tmp/gen/.tmplt.UI.md.def/$target | $SED "s#APP Portal#${portal}#g" | $SED "s/Table/${table}/g" \
      > .target.new
      cat .target.new > $ROOT/tmp/gen/.tmplt.UI.md.def/$target
  done
fi
if [ "$logout" ];then
  cat $ROOT/adm/gen | $SED "s#Log Out#${logout}#g" > .target.new
  cat .target.new > $ROOT/adm/gen
fi

scratch_APP_chk=`ls ${www}/def/common_parts/*_common_menu* 2>/dev/null`

if [ "$scratch_APP_chk" ];then
  for target in `ls ${www}/def/common_parts/*_common_menu* | grep -v .org$ | xargs basename -a`
  do
    app=`echo "${target}" | $AWK -F "_common_menu" '{print $1}'`
    chk_team=`grep "# controller for Scratch APP #team" ${cgi_dir}/${app}`

    if [ -f ${cgi_dir}/${app} -a ! -d ${tmp_dir}/${app} -a ! "${chk_team}" ];then       
      # update UI.md.def
      mkdir ${tmp_dir}/${app}

      id=`sudo -u small-shell $ROOT/bin/DATA_shell authkey:${authkey} databox:${app}.UI.md.def action:get command:head_-1 format:none | awk -F "," '{print $1}'`
      sudo -u small-shell $ROOT/bin/DATA_shell authkey:$authkey databox:${app}.UI.md.def action:get id:${id} key:righth format:none \
      | $SED "s#APP Portal#${portal}#g" | $SED "s/Table/${table}/g" | $SED "s/Log Out/${logout}/g" \
      | $SED "s/_%%enter_/\n/g" | $SED "s/righth://g" > ${tmp_dir}/${app}/righth
      sudo -u small-shell $ROOT/bin/DATA_shell authkey:${authkey} databox:${app}.UI.md.def action:set id:${id} key:righth input_dir:${tmp_dir}/${app}

      # update body
      if [ -f ./tmplt.UI.md.def/body ];then
        cat ./tmplt.UI.md.def/body | $SED "s/%%app/${app}/g" > ${tmp_dir}/${app}/body
        sudo -u small-shell $ROOT/bin/DATA_shell authkey:${authkey} databox:${app}.UI.md.def action:set id:${id} key:body input_dir:${tmp_dir}/${app}
      fi
    fi
  done

  if [ "$permission" = "ro" ];then
    $ROOT/adm/ops set.attr:sys{ro} > /dev/null 2>&1
  fi

  # update team
  if [ -d ./team -a -f ${www}/cgi-bin/team ];then
    rand=`grep team_authkey ${www}/def/common_parts/team_common_menu  | $AWK -F "team_authkey_" '{print $2}'| $AWK -F "\"" '{print $1}'`
    cat ./team/def/common_parts/team_common_menu | $SED "s/%%rand/${rand}/g" > ${www}/def/common_parts/team_common_menu

    if [ -d ./team/def ];then
      for target in `ls ./team/def | xargs basename -a | grep -v common_parts`
      do
        cat ./team/def/${target} | $SED "s#%%www#${www}#g" | $SED "s#%%static_url/#${static_url}#g" > ${www}/def/${target}
      done
    fi

    if [ -d ./team/label ];then
      for target in `ls ./team/label | xargs basename -a`
      do
        cp ./team/label/${target}/* $ROOT/databox/${target}/def/
      done
    fi
    
  fi

  rm -rf ${tmp_dir}/*
fi

echo "package deployment is completed"
exit 0
