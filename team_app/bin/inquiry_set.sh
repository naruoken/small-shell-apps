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

  if [[ $param == id:* ]]; then
    id=`echo $param | awk -F":" '{print $2}'`
  fi

done

# load small-shell path
. ../descriptor/.small_shell_path

# check posted param
if [ -d ../tmp/$session ];then
  keys=`ls ../tmp/$session | sed -z "s/\n/,/g" | sed "s/,$//g"`
else
  echo "error: No param posted"
  exit 1
fi

if [ "$id" = "" ];then
  echo "error: please set correct id"
  exit 1
fi

# insert user_name to inquiry
user_name=`cat ../tmp/$session/user_name`

# -----------------
# Exec command
# -----------------

# BASE COMMAND
META="sudo -u small-shell ${small_shell_path}/bin/meta"
DATA_SHELL="sudo -u small-shell ${small_shell_path}/bin/DATA_shell session:$session pin:$pin app:inquiry"

# push datas to databox

if [ "$id" = "new" ];then
  echo "opened" > ../tmp/$session/status
  keys="$keys,status"
  sed -i "1s/^/#${user_name} from inquiry.app\n/" ../tmp/$session/inquiry
  $DATA_SHELL databox:inquiries action:set id:$id keys:$keys input_dir:../tmp/$session  > ../tmp/$session/result
else
  sed -i "1s/^/#${user_name}\n/" ../tmp/$session/inquiry
  inquiry_chk=`cat ../tmp/$session/inquiry | sed -z "s/\n//g" | sed "s/ //g"`
  if [ "$inquiry_chk" ];then
    $DATA_SHELL databox:inquiries action:merge.set id:$id key:inquiry input_dir:../tmp/$session  >> ../tmp/$session/result
  fi
fi

# result check
updated_id=`cat ../tmp/$session/result | grep "^successfully set" | awk -F "id:" '{print $2}' | sed '/^$/d' | sort | uniq`

# set message
if [ "$updated_id" ];then

  if [ "$id" = "new" ];then
    echo "<h2>SUCCESSFULLY SUBMITTED</h2>" > ../tmp/$session/message
    echo "<a href=\"./inquiry?req=get&id=$updated_id\"><p><b>YOUR LINK</b></p></a>" >> ../tmp/$session/message
  else
    # redirect to the page
    echo "<meta http-equiv=\"refresh\" content=\"0; url=./inquiry?id=$id&req=get\">"
  fi
else
  echo "<h2>Failed, something is wrong. please contact to your web admin</h2>" > ../tmp/$session/message
fi

# -----------------
# render HTML
# -----------------

cat ../descriptor/inquiry_set.html.def | sed -r "s/^( *)</</1" \
| sed "/%%message/r ../tmp/$session/message" \
| sed "s/%%message/$message/g"\
| sed "s/%%id/$id/g"

if [ "$session" ];then
  rm -rf ../tmp/$session
fi

exit 0
