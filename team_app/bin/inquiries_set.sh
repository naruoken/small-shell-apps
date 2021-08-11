#!/bin/bash

# load query string param
for param in `echo $@`
do

  if [[ $param == session:* ]]; then
    session=`echo $param | awk -F":" '{print $2}'`
  fi

  if [[ $param == databox:* ]]; then
    databox=`echo $param | awk -F":" '{print $2}'`
  fi

  if [[ $param == pin:* ]]; then
    pin=`echo $param | awk -F":" '{print $2}'`
  fi

  if [[ $param == id:* ]]; then
    id=`echo $param | awk -F":" '{print $2}'`
  fi

done

# load small-shell path
. ../descriptor/.small_shell_path

# check posted param
if [ -d ../tmp/$session ];then
  keys=`ls ../tmp/$session | sed -z "s/\n/,/g" | sed "s/,$//g"`
else
  echo "error: No param posted"
  exit 1
fi

if [ "$id" = "" ];then
  echo "error: please set correct id"
  exit 1
fi

# -----------------
# Exec command
# -----------------

# BASE COMMAND
META="sudo -u small-shell ${small_shell_path}/bin/meta"
DATA_SHELL="sudo -u small-shell ${small_shell_path}/bin/DATA_shell session:$session pin:$pin app:team"

# push datas to databox

if [ "$id" = "new" ];then
  $DATA_SHELL databox:$databox action:set id:$id keys:$keys input_dir:../tmp/$session  > ../tmp/$session/result
else
  $DATA_SHELL databox:$databox action:set id:$id keys:user_name,email,type,assignee,status input_dir:../tmp/$session  > ../tmp/$session/result
  $DATA_SHELL databox:$databox action:merge.set id:$id key:inquiry input_dir:../tmp/$session  >> ../tmp/$session/result
fi

error_chk=`grep "^error" ../tmp/$session/result`

if [ "$error_chk" ];then
  cat ../descriptor/inquiries_set.html.def | sed "s/^ *</</g" \
  | sed "/%%common_menu/r ../descriptor/common_parts/team_common_menu" \
  | sed "s/%%common_menu//g"\
  | sed "/%%message/r ../tmp/$session/result" \
  | sed "/%%message/d"\
  | sed "s/%%session/session=$session\&pin=$pin/g"
else
  # redirect to the table
  echo "<meta http-equiv=\"refresh\" content=\"0; url=./team?subapp=inquiries&session=$session&pin=$pin&req=table\">"
fi

if [ "$session" ];then
  rm -rf ../tmp/$session
fi

exit 0
