#!/bin/bash

# Target databox and keys
databox=tasks
#keys=all

# load small-shell conf
. %%www/descriptor/.small_shell_conf

# load query string param
for param in `echo $@`
do

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

  if [ "$master" ];then
    if [[ $param == redirect* ]];then
      redirect=`echo $param | $AWK -F":" '{print $2}'`
    fi
  fi

done

if [ ! "$id"  ];then
  id="new"
fi

if [ ! -d %%www/tmp/$session ];then
  mkdir %%www/tmp/$session
fi

# SET BASE_COMMAND
META="${small_shell_path}/bin/meta"
DATA_SHELL="${small_shell_path}/bin/DATA_shell session:$session pin:$pin app:team"

# load permission
permission=`$META get.attr:team/$user_name{permission}`

if [ $id = "new" ];then

  #----------------------------
  # gen read/write form #new
  #----------------------------
  $DATA_SHELL databox:$databox action:get id:$id keys:all format:html_tag > %%www/tmp/$session/dataset

else

  #---------------------------
  # gen read/write form #update
  #---------------------------
  $DATA_SHELL databox:$databox action:get id:$id keys:hashid,name,start,end,assign,status,sync,description format:html_tag > %%www/tmp/$session/dataset

  # add updates
  $DATA_SHELL databox:$databox action:merge.get id:$id key:update > %%www/tmp/$session/update
  null_chk=`cat %%www/tmp/$session/update`

  if [ "$null_chk" ];then
    cat  %%www/tmp/$session/update  >> %%www/tmp/$session/dataset
  fi

  #---------------------------
  # gen read only datas
  #---------------------------
  #$DATA_SHELL databox:tasks action:get id:$id keys:%%keys format:none > %%www/tmp/$session/dataset.0.1
  #cat %%www/tmp/$session/dataset.0.1 | $SED "s/^/<li><label>/g" | $SED "s/:/<\/label><p>/g" | $SED "s/$/<\/p><\/li>/g" \
  #| $SED "s/<p><\/p>/<p>-<\/p>/g" >> %%www/tmp/$session/dataset

fi

# error check
error_chk=`cat %%www/tmp/$session/dataset | grep "^error:" | uniq`

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

# overwritten by clustering logic
if [ "$master" -a "$permission" = "rw" ];then
  if [ "$redirect" = "no" ];then
    if [ "$id" = "new" ];then
      view="tasks_get_new_master_failed.html.def"
    else
      view="tasks_get_rw_master_failed.html.def"
    fi
  fi
fi

# render HTML
cat %%www/descriptor/${view} | $SED -r "s/^( *)</</1" \
| $SED "/%%common_menu/r %%www/descriptor/common_parts/team_common_menu" \
| $SED "/%%common_menu/d" \
| $SED "/%%dataset/r %%www/tmp/$session/dataset" \
| $SED "s/%%dataset//g"\
| $SED "/%%history/r %%www/tmp/$session/history" \
| $SED "s/%%history//g"\
| $SED "s/%%id/$id/g" \
| $SED "s/+MERGE /<\/pre><pre class=\"task\">/g" \
| $SED "s/<pre><\/pre>//g" \
| $SED "s/%%pdls/session=$session\&pin=$pin\&req=get/g" \
| $SED "s/%%session/session=$session\&pin=$pin/g" \
| $SED "s/%%params/subapp=tasks\&session=$session\&pin=$pin/g"


if [ "$session" ];then
  rm -rf %%www/tmp/$session
fi

exit 0
