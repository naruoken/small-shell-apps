#!/bin/bash

# Target databox and keys
databox=events

# load small-shell conf
. ../descriptor/.small_shell_conf

# load query string param
for param in `echo $@`
do

  if [[ $param == session:* ]]; then
    session=`echo $param | $AWK -F":" '{print $2}'`
  fi

  if [[ $param == pin:* ]]; then
    pin=`echo $param | $AWK -F":" '{print $2}'`
  fi

  if [[ $param == id:* ]]; then
    id=`echo $param | $AWK -F":" '{print $2}'`
  fi

done

# check posted param
if [ -d ../tmp/$session ];then
  keys=`ls ../tmp/$session | $SED -z "s/\n/,/g" | $SED "s/,$//g"`
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

# form type check
form_chk=`$META chk.form:$databox`
if [ "$form_chk" = "multipart" ];then
   file_key=`cat ../tmp/$session/binary_file/input_name`
   cat ../tmp/$session/binary_file/file_name > ../tmp/$session/$file_key 2>/dev/null
fi

# push datas to databox
$DATA_SHELL databox:$databox action:set id:$id keys:$keys input_dir:../tmp/$session  > ../tmp/$session/result

error_chk=`grep "^error" ../tmp/$session/result`

if [ "$error_chk" ];then
  cat ../descriptor/team_set_err.html.def | $SED -r "s/^( *)</</1" \
  | $SED "/%%common_menu/r ../descriptor/common_parts/team_common_menu" \
  | $SED "s/%%common_menu//g"\
  | $SED "/%%message/r ../tmp/$session/result" \
  | $SED "/%%message/d"\
  | $SED "s/%%session/session=$session\&pin=$pin/g"
else
  # redirect to the table
  echo "<meta http-equiv=\"refresh\" content=\"0; url=./team?session=$session&pin=$pin&req=main\">"
fi

if [ "$session" ];then
  rm -rf ../tmp/$session
fi

exit 0
