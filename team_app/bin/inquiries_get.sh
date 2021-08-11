#!/bin/bash

# Target databox and keys
#keys=%%keys

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

  if [[ $param == user_name:* ]]; then
    user_name=`echo $param | awk -F":" '{print $2}'`
  fi

  if [[ $param == id:* ]]; then
    id=`echo $param | awk -F":" '{print $2}'`
  fi

done

# load small-shell path
. ../descriptor/.small_shell_path

if [ ! "$id"  ];then
  id="new"
fi

if [ ! -d ../tmp/$session ];then
  mkdir ../tmp/$session
fi

# SET BASE_COMMAND
META="sudo -u small-shell ${small_shell_path}/bin/meta"
DATA_SHELL="sudo -u small-shell ${small_shell_path}/bin/DATA_shell session:$session pin:$pin app:team"

if [ $id = "new" ];then

  #----------------------------
  # gen reqd/write form #new
  #----------------------------
  $DATA_SHELL databox:$databox action:get id:$id keys:all format:html_tag > ../tmp/$session/dataset

else

  #---------------------------
  # gen reqd/write form #update
  #---------------------------
  $DATA_SHELL databox:$databox action:get id:$id keys:hashid,user_name,email,type,assignee,status format:html_tag > ../tmp/$session/dataset
  $DATA_SHELL databox:$databox action:merge.get id:$id key:inquiry >> ../tmp/$session/dataset

  #---------------------------
  # gen read only datas
  #---------------------------
  #$DATA_SHELL databox:%%databox action:get id:$id keys:%%keys format:none > ../tmp/$session/dataset.0.1
  #cat ../tmp/$session/dataset.0.1 | sed "s/^/<li><label>/g" | sed "s/:/<\/label><p>/g" | sed "s/$/<\/p><\/li>/g" \
  #| sed "s/<p><\/p>/<p>-<\/p>/g" >> ../tmp/$session/dataset

fi

# error check
err_chk=`grep "error: there is no key:%%keys" ../tmp/$session/dataset`

if [ "$err_chk" ];then
  echo "<h2>Oops please define keys in inquiries_get.sh for getting data</h2>"
  if [ "$session" ];then
    rm -rf ../tmp/$session
  fi
  exit 1
fi


# render HTML
if [ "$id" = "new" ];then
  cat ../descriptor/inquiries_new.html.def | sed "s/^ *</</g" \
  | sed "/%%common_menu/r ../descriptor/common_parts/team_common_menu" \
  | sed "/%%common_menu/d" \
  | sed "/%%dataset/r ../tmp/$session/dataset" \
  | sed "s/%%dataset//g"\
  | sed "s/%%id/$id/g" \
  | sed "s/%%pdls/session=$session\&pin=$pin\&req=get/g" \
  | sed "s/%%session/session=$session\&pin=$pin/g" \
  | sed "s/%%params/session=$session\&subapp=inquiries\&pin=$pin\&databox=$databox/g"
else
  cat ../descriptor/inquiries_get.html.def | sed "s/^ *</</g" \
  | sed "/%%common_menu/r ../descriptor/common_parts/team_common_menu" \
  | sed "/%%common_menu/d" \
  | sed "/%%dataset/r ../tmp/$session/dataset" \
  | sed "s/%%dataset//g"\
  | sed "/%%history/r ../tmp/$session/history" \
  | sed "s/%%history//g"\
  | sed "s/%%id/$id/g" \
  | sed "s/%%pdls/session=$session\&pin=$pin\&req=get/g" \
  | sed "s/%%session/session=$session\&pin=$pin/g" \
  | sed "s/%%params/session=$session\&subapp=inquiries\&pin=$pin\&databox=$databox/g"
fi

if [ "$session" ];then
  rm -rf ../tmp/$session
fi

exit 0
