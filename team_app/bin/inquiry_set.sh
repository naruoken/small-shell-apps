#!/bin/bash

# load small-shell conf
. /var/www/descriptor/.small_shell_conf

# load query string param
for param in `echo $@`
do

  if [[ $param == session:* ]]; then
    session=`echo $param | $AWK -F":" '{print $2}'`
  fi

  if [[ $param == pin:* ]]; then
    pin=`echo $param | $AWK -F":" '{print $2}'`
  fi

  if [[ $param == id:* ]]; then
    id=`echo $param | $AWK -F":" '{print $2}'`
  fi

done

# check posted param
if [ -d /var/www/tmp/$session ];then
  keys=`ls /var/www/tmp/$session | $SED -z "s/\n/,/g" | $SED "s/,$//g"`
else
  echo "error: No param posted"
  exit 1
fi

if [ "$id" = "" ];then
  echo "error: please set correct id"
  exit 1
fi

# insert user_name to inquiry
user_name=`cat /var/www/tmp/$session/user_name`

# -----------------
# Exec command
# -----------------

# BASE COMMAND
META="${small_shell_path}/bin/meta"
DATA_SHELL="${small_shell_path}/bin/DATA_shell session:$session pin:$pin app:inquiry"

# push datas to databox

if [ "$id" = "new" ];then
  echo "opened" > /var/www/tmp/$session/status
  keys="$keys,status"
  $SED -i "1s/^/#${user_name} from inquiry.app\n/" /var/www/tmp/$session/inquiry
  $DATA_SHELL databox:inquiries action:set id:$id keys:$keys input_dir:/var/www/tmp/$session  > /var/www/tmp/$session/result
else
  $SED -i "1s/^/#${user_name}\n/" /var/www/tmp/$session/inquiry
  inquiry_chk=`cat /var/www/tmp/$session/inquiry | $SED -z "s/\n//g" | $SED "s/ //g"`
  if [ "$inquiry_chk" ];then
    $DATA_SHELL databox:inquiries action:merge.set id:$id key:inquiry input_dir:/var/www/tmp/$session  >> /var/www/tmp/$session/result
  fi
fi

# result check
updated_id=`cat /var/www/tmp/$session/result | grep "^successfully set" | $AWK -F "id:" '{print $2}' | $SED '/^$/d' | sort | uniq`

# set message
if [ "$updated_id" ];then

  if [ "$id" = "new" ];then
    echo "<h2>問い合わせを受け付けました、以下リンク先にて順次回答させていただきます</h2>" > /var/www/tmp/$session/message
    echo "<a href=\"./inquiry?req=get&id=$updated_id\"><p><b>YOUR LINK</b></p></a>" >> /var/www/tmp/$session/message
  else
    # redirect to the page
    echo "<meta http-equiv=\"refresh\" content=\"0; url=./inquiry?id=$id&req=get\">"
  fi
else
  echo "<h2>Failed, something is wrong. please contact to your web admin</h2>" > /var/www/tmp/$session/message
fi

# -----------------
# render HTML
# -----------------

cat /var/www/descriptor/inquiry_set.html.def | $SED -r "s/^( *)</</1" \
| $SED "/%%message/r /var/www/tmp/$session/message" \
| $SED "s/%%message/$message/g"

if [ "$session" ];then
  rm -rf /var/www/tmp/$session
fi

exit 0
