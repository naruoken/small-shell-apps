#!/bin/bash

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

done

if [ ! -d %%www/tmp/$session ];then
  mkdir %%www/tmp/$session
fi

# -----------------
# Exec command
# -----------------

# SET BASE_COMMAND
META="sudo -u small-shell ${small_shell_path}/bin/meta"
DATA_SHELL="sudo -u small-shell ${small_shell_path}/bin/DATA_shell session:$session pin:$pin app:team"

# load permission
permission=`$META get.attr:team/$user_name{permission}`

# gen event json
$DATA_SHELL databox:events command:show_all[keys=name,start,end,color][filter=sync{yes}] format:json \
| $SED "s/{%%%%%%%%%%%%%%%%%}/'/g"\
| $SED "s/{%%%%%%%%%%%%%%%%}/%/g"\
| $SED "s/{%%%%%%%%%%%%%%%}/*/g"\
| $SED "s/{%%%%%%%%%%%%%%}/$/g"\
| $SED "s/{%%%%%%%%%%%%%}/\#/g"\
| $SED "s/{%%%%%%%%%%%%}/|/g"\
| $SED "s/{%%%%%%%%%%%}/\]/g"\
| $SED "s/{%%%%%%%%%%}/\[/g"\
| $SED "s/{%%%%%%%%%}/)/g"\
| $SED "s/{%%%%%%%%}/(/g"\
| $SED "s/{%%%%%%%}/_/g"\
| $SED "s/{%%%%%%}/,/g"\
| $SED "s/{%%%%%}/\//g"\
| $SED "s/{%%%%}/\&/g"\
| $SED "s/{%%%}/:/g"  > %%www/tmp/$session/events

# gen tasks json
$DATA_SHELL databox:tasks command:show_all[keys=name,start,end,status][filter=sync{yes}] format:json \
| $SED "s/{%%%%%%%%%%%%%%%%%}/'/g"\
| $SED "s/{%%%%%%%%%%%%%%%%}/%/g"\
| $SED "s/{%%%%%%%%%%%%%%%}/*/g"\
| $SED "s/{%%%%%%%%%%%%%%}/$/g"\
| $SED "s/{%%%%%%%%%%%%%}/\#/g"\
| $SED "s/{%%%%%%%%%%%%}/|/g"\
| $SED "s/{%%%%%%%%%%%}/\]/g"\
| $SED "s/{%%%%%%%%%%}/\[/g"\
| $SED "s/{%%%%%%%%%}/)/g"\
| $SED "s/{%%%%%%%%}/(/g"\
| $SED "s/{%%%%%%%}/_/g"\
| $SED "s/{%%%%%%}/,/g"\
| $SED "s/{%%%%%}/\//g"\
| $SED "s/{%%%%}/\&/g"\
| $SED "s/{%%%}/:/g"  > %%www/tmp/$session/tasks

# merge events and tasks to 1 array
$JQ -s add %%www/tmp/$session/events %%www/tmp/$session/tasks > %%www/tmp/$session/merged_events

# -----------------
# render HTML
# -----------------

cat %%www/descriptor/team_main.html.def | $SED -r "s/^( *)</</1" \
| $SED "/%%common_menu/r %%www/descriptor/common_parts/team_common_menu" \
| $SED "s/%%common_menu//g"\
| $SED "/%%team_main_menu/r %%www/descriptor/common_parts/team_main_menu_${permission}" \
| $SED "s/%%team_main_menu//g"\
| $SED "s/%%user_name/$user_name/g" \
| $SED "/%%json/r %%www/tmp/$session/merged_events"\
| $SED "s/%%json//g"\
| $SED "s/%%common_menu//g"\
| $SED "s/%%session/session=$session\&pin=$pin/g" 

if [ "$session" ];then
  rm -rf %%www/tmp/$session
fi

exit 0
