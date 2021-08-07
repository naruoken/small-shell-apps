#!/bin/bash

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

  if [[ $param == id:* ]]; then
    id=`echo $param | awk -F":" '{print $2}'`
  fi

done

# load small-shell path
. ../descriptor/.small_shell_path

if [ ! -d ../tmp/${session}_log ];then
  mkdir ../tmp/${session}_log
fi

# SET BASE_COMMAND
META="sudo -u small-shell ${small_shell_path}/bin/meta"
DATA_SHELL="sudo -u small-shell ${small_shell_path}/bin/DATA_shell session:$session pin:$pin app:drive"

# -----------------
# Exec command
# -----------------

# gen %%log contents
$DATA_SHELL databox:$databox \
action:get id:$id type:log format:html_tag > ../tmp/${session}_log/log

# render HTML
cat ../descriptor/drive_log_viewer.html.def | sed "s/^ *</</g" \
| sed "/%%log/r ../tmp/${session}_log/log" \
| sed "s/%%log//g"\
| sed "s/%%id/$id/g"

if [ "$session" ];then
  rm -rf ../tmp/${session}_log
fi

exit 0
