#!/bin/bash

# Target databox and keys
databox=tasks

# load small-shell conf
. %%www/def/.env

# load query string param
for param in $(echo $@)
do

  if [[ $param == session:* ]]; then
    session=$(echo "$param" | $AWK -F":" '{print $2}')
  fi

  if [[ $param == pin:* ]]; then
    pin=$(echo "$param" | $AWK -F":" '{print $2}')
  fi

  if [[ $param == user_name:* ]]; then
    user_name=$(echo "$param" | $AWK -F":" '{print $2}')
  fi

  if [[ $param == id:* ]]; then
    id=$(echo "$param" | $AWK -F":" '{print $2}')
  fi

done

# load small-shell conf
. %%www/def/.env

# check posted param
if [ -d %%www/tmp/${session} ];then
  keys=$(ls %%www/tmp/${session} | $SED -z "s/\n/,/g" | $SED "s/,$//g" | $SED "s/update//g")
else
  echo "error: No param posted"
  exit 1
fi

if [ "$id" = "" ];then
  echo "error: please set correct id"
  exit 1
fi

if [ -f %%www/tmp/${session}/update ];then
  null_chk=$(cat %%www/tmp/${session}/update | $SED "s/ //g")
  if [ ! "$null_chk" ];then
    rm %%www/tmp/${session}/update
  fi
fi

# -----------------
# Exec command
# -----------------

# BASE COMMAND
META="${small_shell_path}/bin/meta"
DATA_SHELL="${small_shell_path}/bin/DATA_shell session:$session pin:$pin app:team"

# form type check
form_chk=$($META chk.form:$databox)
if [ "$form_chk" = "multipart" ];then
   file_key=$(cat %%www/tmp/${session}/binary_file/input_name)
   cat %%www/tmp/${session}/binary_file/file_name > %%www/tmp/${session}/${file_key} 2>/dev/null
fi

# push datas to databox
$DATA_SHELL databox:$databox action:set id:$id keys:$keys \
input_dir:%%www/tmp/${session}  > %%www/tmp/${session}/result

if [ "$id" = "new" ];then
  # update id
  id=$(cat %%www/tmp/${session}/result | $AWK -F "id:" '{print $2}' | $SED '/^$/d' | sort | uniq)
fi

inquiry_chk=$(cat %%www/tmp/${session}/update | $SED -z "s/\n//g" | $SED "s/ //g")
if [ "$inquiry_chk" ];then
  $DATA_SHELL databox:$databox action:merge.set id:$id key:update input_dir:%%www/tmp/${session}  >> %%www/tmp/${session}/result
fi

error_chk=$(grep "^error" %%www/tmp/${session}/result)

if [ "$error_chk" ];then
  cat %%www/def/tasks_set_err.html.def | $SED -r "s/^( *)</</1" \
  | $SED "/%%common_menu/r %%www/def/common_parts/team_common_menu" \
  | $SED "s/%%common_menu//g"\
  | $SED "s/%%user/${user_name}/g"\
  | $SED "/%%message/r %%www/tmp/${session}/result" \
  | $SED "/%%message/d"\
  | $SED "s/%%session/session=${session}\&pin=${pin}/g"
else
  echo "<meta http-equiv=\"refresh\" content=\"0; url=./team?subapp=tasks&session=$session&pin=$pin&req=get&id=${id}\">"
fi

if [ "$session" ];then
  rm -rf %%www/tmp/${session}
fi

exit 0
