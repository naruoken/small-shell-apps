#!/bin/bash

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

done

# load small-shell path
. ../descriptor/.small_shell_path

if [ ! -d ../tmp/$session ];then
  mkdir ../tmp/$session
fi

# -----------------
# Exec command
# -----------------

# SET BASE_COMMAND
META="sudo -u small-shell ${small_shell_path}/bin/meta"
DATA_SHELL="sudo -u small-shell ${small_shell_path}/bin/DATA_shell session:$session pin:$pin app:team"

# gen event json
$DATA_SHELL databox:events command:show_all[keys=name,start,end,color][filter=sync{yes}] format:json \
| sed "s/{%%%%%%%%%%%%%%%%%}/'/g"\
| sed "s/{%%%%%%%%%%%%%%%%}/%/g"\
| sed "s/{%%%%%%%%%%%%%%%}/*/g"\
| sed "s/{%%%%%%%%%%%%%%}/$/g"\
| sed "s/{%%%%%%%%%%%%%}/\#/g"\
| sed "s/{%%%%%%%%%%%%}/|/g"\
| sed "s/{%%%%%%%%%%%}/\]/g"\
| sed "s/{%%%%%%%%%%}/\[/g"\
| sed "s/{%%%%%%%%%}/)/g"\
| sed "s/{%%%%%%%%}/(/g"\
| sed "s/{%%%%%%%}/_/g"\
| sed "s/{%%%%%%}/,/g"\
| sed "s/{%%%%%}/\//g"\
| sed "s/{%%%%}/\&/g"\
| sed "s/{%%%}/:/g"  > ../tmp/$session/events

# gen tasks json
$DATA_SHELL databox:tasks command:show_all[keys=name,start,end,status][filter=sync{yes}] format:json \
| sed "s/{%%%%%%%%%%%%%%%%%}/'/g"\
| sed "s/{%%%%%%%%%%%%%%%%}/%/g"\
| sed "s/{%%%%%%%%%%%%%%%}/*/g"\
| sed "s/{%%%%%%%%%%%%%%}/$/g"\
| sed "s/{%%%%%%%%%%%%%}/\#/g"\
| sed "s/{%%%%%%%%%%%%}/|/g"\
| sed "s/{%%%%%%%%%%%}/\]/g"\
| sed "s/{%%%%%%%%%%}/\[/g"\
| sed "s/{%%%%%%%%%}/)/g"\
| sed "s/{%%%%%%%%}/(/g"\
| sed "s/{%%%%%%%}/_/g"\
| sed "s/{%%%%%%}/,/g"\
| sed "s/{%%%%%}/\//g"\
| sed "s/{%%%%}/\&/g"\
| sed "s/{%%%}/:/g"  > ../tmp/$session/tasks

# gen announcement
top_news=`$DATA_SHELL databox:announcements command:head_-1 format:none`
top_news="`echo $top_news | awk -F "," '{print $3}' | head -c 10`.."


# merge events and tasks to 1 array
jq -s add ../tmp/$session/events ../tmp/$session/tasks > ../tmp/$session/merged_events

# -----------------
# render HTML
# -----------------

cat ../descriptor/team_main.html.def | sed "s/^ *</</g" \
| sed "/%%common_menu/r ../descriptor/common_parts/team_common_menu" \
| sed "s/%%common_menu//g"\
| sed "s/%%user_name/$user_name/g" \
| sed "/%%json/r ../tmp/$session/merged_events"\
| sed "s/%%json//g"\
| sed "s/%%top/$top_news/g"\
| sed "s/%%common_menu//g"\
| sed "s/%%session/session=$session\&pin=$pin/g" 

if [ "$session" ];then
  rm -rf ../tmp/$session
fi

exit 0
