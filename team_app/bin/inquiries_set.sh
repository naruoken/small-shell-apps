#!/bin/bash

# Target databox and keys
databox=inquiries

# load query string param
for param in `echo $@`
do

  if [[ $param == session:* ]]; then
    session=`echo $param | awk -F":" '{print $2}'`
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

if [ -f ../tmp/$session/inquiry ];then
  null_chk=`cat ../tmp/$session/inquiry | sed "s/ //g"`
  if [ ! "$null_chk" ];then
    rm ../tmp/$session/inquiry
  fi
fi

# check posted param
if [ -d ../tmp/$session ];then
  keys=`ls ../tmp/$session | sed -z "s/\n/,/g" | sed "s/,$//g" | sed "s/inquiry//g"`
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

if [ "$id" = "new" ];then
  # update id
  id=`cat ../tmp/$session/result | awk -F "id:" '{print $2}' | sed '/^$/d' | sort | uniq`
fi

inquiry_chk=`cat ../tmp/$session/inquiry | sed -z "s/\n//g" | sed "s/ //g"`
if [ "$inquiry_chk" ];then
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
  echo "<meta http-equiv=\"refresh\" content=\"0; url=./team?subapp=inquiries&session=$session&pin=$pin&req=get&id=$id\">"
fi

#if [ "$session" ];then
#  rm -rf ../tmp/$session
#fi

exit 0
