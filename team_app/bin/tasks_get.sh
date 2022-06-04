#!/bin/bash

# Target databox and keys
databox=tasks
#keys=all

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

# load permission
permission=`$META get.attr:team/$user_name{permission}`

if [ $id = "new" ];then

  #----------------------------
  # gen reqd/write form #new
  #----------------------------
  $DATA_SHELL databox:$databox action:get id:$id keys:all format:html_tag > ../tmp/$session/dataset

else

  #---------------------------
  # gen reqd/write form #update
  #---------------------------
  $DATA_SHELL databox:$databox action:get id:$id keys:hashid,name,start,end,assign,status,sync,description format:html_tag > ../tmp/$session/dataset

  # add updates
  $DATA_SHELL databox:$databox action:merge.get id:$id key:update > ../tmp/$session/update
  null_chk=`cat ../tmp/$session/update`

  if [ "$null_chk" ];then
    cat  ../tmp/$session/update  >> ../tmp/$session/dataset
  fi

  #---------------------------
  # gen read only datas
  #---------------------------
  #$DATA_SHELL databox:tasks action:get id:$id keys:%%keys format:none > ../tmp/$session/dataset.0.1
  #cat ../tmp/$session/dataset.0.1 | sed "s/^/<li><label>/g" | sed "s/:/<\/label><p>/g" | sed "s/$/<\/p><\/li>/g" \
  #| sed "s/<p><\/p>/<p>-<\/p>/g" >> ../tmp/$session/dataset

fi

# error check
error_chk=`cat ../tmp/$session/dataset | grep "^error:" | uniq`

# form type check
form_chk=`$META chk.form:$databox`

# set view
if [ "$error_chk" ];then
  view="tasks_get_err.html.def" 

elif [ "$permission"  = "ro" ];then
  view="tasks_get_ro.html.def"

elif [ "$form_chk" = "urlenc" ];then
  if [ "$id" = "new" ];then
    view="tasks_get_new.html.def"
  else
    view="tasks_get_rw.html.def"
  fi
elif [ "$form_chk" = "multipart" ];then
  if [ "$id" = "new" ];then
    view="tasks_get_new_incf.html.def"
  else
    view="tasks_get_rw_incf.html.def"
  fi
fi

# render HTML
cat ../descriptor/${view} | sed -r "s/^( *)</</1" \
| sed "/%%common_menu/r ../descriptor/common_parts/team_common_menu" \
| sed "/%%common_menu/d" \
| sed "/%%dataset/r ../tmp/$session/dataset" \
| sed "s/%%dataset//g"\
| sed "/%%history/r ../tmp/$session/history" \
| sed "s/%%history//g"\
| sed "s/%%id/$id/g" \
| sed "s/+MERGE /<\/pre><pre class=\"adm\">/g" \
| sed "s/<pre><\/pre>//g" \
| sed "s/%%pdls/session=$session\&pin=$pin\&req=get/g" \
| sed "s/%%session/session=$session\&pin=$pin/g" \
| sed "s/%%params/subapp=tasks\&session=$session\&pin=$pin/g"


if [ "$session" ];then
  rm -rf ../tmp/$session
fi

exit 0
