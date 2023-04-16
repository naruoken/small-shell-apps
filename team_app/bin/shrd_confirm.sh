#!/bin/bash

# Target databox and keys
databox=drive
keys=all

# load small-shell conf
. %%www/descriptor/.small_shell_conf

# load query string param
for param in `echo $@`
do

  if [[ $param == remote_addr:* ]]; then
    remote_addr=`echo $param | $AWK -F":" '{print $2}'`
  fi

  if [[ $param == session:* ]]; then
    session=`echo $param | $AWK -F":" '{print $2}'`
  fi

  if [[ $param == pin:* ]]; then
    pin=`echo $param | $AWK -F":" '{print $2}'`
  fi

  if [[ $param == user_name:* ]]; then
    user_name=`echo $param | $AWK -F":" '{print $2}'`
  fi

  if [[ $param == id:* ]]; then
    id=`echo $param | $AWK -F":" '{print $2}'`
  fi

done

if [ ! -d %%www/tmp/$session ];then
  mkdir %%www/tmp/$session
fi

# SET BASE_COMMAND
META="${small_shell_path}/bin/meta"
DATA_SHELL="${small_shell_path}/bin/DATA_shell session:$session pin:$pin"

# null chk
null_chk=`$META chk.null:$databox{$id} | grep hashid | awk -F ":" '{print $2}'`
if [ ! $null_chk -eq 1 ];then
  error_chk=error
else
  scope=`$DATA_SHELL databox:drive action:get key:share id:$id format:none | $SED "s/share://g"`
  if [ "$scope" = "share to external" ];then
    filename_with_size=`$DATA_SHELL databox:$databox action:get key:file id:$id format:none | $SED "s/file://g"`
    filename=`echo $filename_with_size | $AWK -F " #" '{print $1}' | $SED "s/ /_/g"`
  else
    error_chk=error
  fi
fi

# set view
if [ "$error_chk" ];then
  view="shrd_err.html.def"
else
  view="shrd_confirm.html.def"
fi

# render HTML
cat %%www/descriptor/${view} | $SED -r "s/^( *)</</1" \
| $SED "s/%%remote_addr/$remote_addr/g" \
| $SED "s/%%filename_with_size/$filename_with_size/g" \
| $SED "s/%%filename/$filename/g" \
| $SED "s/%%id/$id/g" 

if [ "$session" ];then
  rm -rf %%www/tmp/$session
fi

exit 0
