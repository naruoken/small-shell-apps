#!/bin/bash

# Target databox and keys
databox=announcements
keys=all

# load query string param
for param in `echo $@`
do

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
  $DATA_SHELL databox:$databox action:get id:$id keys:$keys format:html_tag > ../tmp/$session/dataset

else

  #---------------------------
  # gen reqd/write form #update
  #---------------------------
  $DATA_SHELL databox:$databox action:get id:$id keys:$keys format:html_tag > ../tmp/$session/dataset

  #---------------------------
  # gen read only datas
  #---------------------------
  #$DATA_SHELL databox:announcements action:get id:$id keys:%%keys format:none > ../tmp/$session/dataset.0.1
  #cat ../tmp/$session/dataset.0.1 | sed "s/^/<li><label>/g" | sed "s/:/<\/label><p>/g" | sed "s/$/<\/p><\/li>/g" \
  #| sed "s/<p><\/p>/<p>-<\/p>/g" >> ../tmp/$session/dataset

fi

# error check
error_chk=`cat ../tmp/$session/dataset | grep "^error: there is no primary_key:"`

# form type check
form_chk=`$META chk.form:$databox`

# set view
if [ "$error_chk" ];then
  echo "<h2>Oops please something must be wrong, please check  announcements_get.sh</h2>"

elif [ "$form_chk" = "urlenc" ];then
  if [ "$id" = "new" ];then
    view="announcements_get_new.html.def"
  else
    view="announcements_get.html.def"
  fi
elif [ "$form_chk" = "multipart" ];then
  if [ "$id" = "new" ];then
    view="announcements_get_new_incf.html.def"
  else
    view="announcements_get_incf.html.def"
  fi
fi

# render HTML
cat ../descriptor/${view} | sed "s/^ *</</g" \
| sed "/%%common_menu/r ../descriptor/common_parts/team_common_menu" \
| sed "/%%common_menu/d" \
| sed "/%%dataset/r ../tmp/$session/dataset" \
| sed "s/%%dataset//g"\
| sed "/%%history/r ../tmp/$session/history" \
| sed "s/%%history//g"\
| sed "s/%%id/$id/g" \
| sed "s/%%pdls/session=$session\&pin=$pin\&req=get/g" \
| sed "s/%%session/session=$session\&pin=$pin/g" \
| sed "s/%%params/subapp=announcements\&session=$session\&pin=$pin/g"


if [ "$session" ];then
  rm -rf ../tmp/$session
fi

exit 0