#!/bin/bash

# load query string param
for param in `echo $@`
do

  if [[ $param == databox:* ]]; then
    databox=`echo $param | awk -F":" '{print $2}'`
  fi

  if [[ $param == session:* ]]; then
    session=`echo $param | awk -F":" '{print $2}'`
  fi

  if [[ $param == pin:* ]]; then
    pin=`echo $param | awk -F":" '{print $2}'`
  fi

  if [[ $param == user_name:* ]]; then
    user_name=`echo $param | awk -F":" '{print $2}'`
  fi

  if [[ $param == id:* ]]; then
    id=`echo $param | awk -F":" '{print $2}'`
  fi

done

# load small-shell path
. ../descriptor/.small_shell_path

# check posted param

if [ "$id" = "" ];then
  echo "error: please set correct id"
  exit 1
fi

if [ ! "$databox" = "library.db" ];then
  echo "error: please set correct databox"
  exit 1
fi

if [ ! -d ../tmp/$session ];then
  mkdir ../tmp/$session
fi

# gen databox list for left menu
db_list="$databox `${small_shell_path}/bin/meta get.databox`"
count=0
for db in $db_list
do
  if [ ! "$databox" = "$db" -o $count -eq 0 ];then
    echo "<option value=\"./controller?session=$session&pin=$pin&databox=$db&req=console\">DataBox:$db</option>"\
    >> ../tmp/$session/databox_list
  fi
  ((count +=1 ))
done

# -----------------
# Exec command
# -----------------

# SET BASE_COMMAND
META="sudo -u small-shell ${small_shell_path}/bin/meta"
DATA_SHELL="sudo -u small-shell ${small_shell_path}/bin/DATA_shell session:$session pin:$pin"

# get issue id
issue_id=`$DATA_SHELL databox:library.db id:$id key:issue_id action:get format:none | awk -F "issue_id:" '{print $2}'`

# gen %%result contents
$DATA_SHELL databox:library.db action:set id:$id key:status value:available  > ../tmp/$session/result
$DATA_SHELL databox:library.db action:set id:$id key:issue_id value:%%null  >> ../tmp/$session/result
$DATA_SHELL databox:issue.db action:set id:$issue_id key:status value:closed  >> ../tmp/$session/result

updated_id=`cat ../tmp/$session/result | grep "^successfully set" | awk '{print $3}' | uniq`

# -----------------
# render HTML
# -----------------

if [ "$updated_id" ];then
  message="! serch index will be updated soon"
  result="UPDATED"
else
  message=".."
  result="! NO UPDATE"
fi

cat ../descriptor/library_release.html.def | sed "s/^ *</</g" \
| sed "/%%databox_list/r ../tmp/$session/databox_list" \
| sed "s/%%databox_list//g"\
| sed "/%%common_menu_rw/r ../descriptor/common_parts/common_menu_rw" \
| sed "s/%%common_menu_rw//g"\
| sed "/%%footer/r ../descriptor/common_parts/footer" \
| sed "/%%footer/d"\
| sed "/%%result/r ../tmp/$session/result" \
| sed "s/%%result/$result/g"\
| sed "s/%%id/$id/g"\
| sed "s/%%library_id/$id/g"\
| sed "s/%%issue_id/$issue_id/g"\
| sed "s/%%message/$message/g"\
| sed "s/%%params/session=$session\&pin=$pin\&databox=$databox/g"

if [ "$session" ];then
  rm -rf ../tmp/$session
fi

exit 0
