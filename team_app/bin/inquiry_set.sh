#!/bin/bash

# load small-shell conf
. %%www/def/.env

# load query string param
for param in $(echo $@)
do

  if [[ $param == session:* ]]; then
    session=$(echo "$param" | $AWK -F":" '{print $2}')
  fi

  if [[ $param == pin:* ]]; then
    pin=$(echo "$param" | $AWK -F":" '{print $2}')
  fi

  if [[ $param == id:* ]]; then
    id=$(echo "$param" | $AWK -F":" '{print $2}')
  fi

done

# check posted param
if [ -d %%www/tmp/${session} ];then
  keys=$(ls %%www/tmp/${session} | $SED -z "s/\n/,/g" | $SED "s/,$//g")
else
  echo "error: No param posted"
  exit 1
fi

if [ "$id" = "" ];then
  echo "error: please set correct id"
  exit 1
fi

# insert user_name to inquiry
user_name=$(cat %%www/tmp/${session}/user_name)

# -----------------
# Exec command
# -----------------

# BASE COMMAND
META="${small_shell_path}/bin/meta"
DATA_SHELL="${small_shell_path}/bin/DATA_shell session:$session pin:$pin app:inquiry"

# push datas to databox

if [ "$id" = "new" ];then
  echo "opened" > %%www/tmp/${session}/status
  keys="$keys,status"
  $SED -i "1s/^/#${user_name} from inquiry.app\n/" %%www/tmp/${session}/inquiry
  $DATA_SHELL databox:inquiries action:set id:$id keys:$keys input_dir:%%www/tmp/${session}  > %%www/tmp/${session}/result
else
  $SED -i "1s/^/#${user_name}\n/" %%www/tmp/${session}/inquiry
  inquiry_chk=$(cat %%www/tmp/${session}/inquiry | $SED -z "s/\n//g" | $SED "s/ //g")
  if [ "$inquiry_chk" ];then
    $DATA_SHELL databox:inquiries action:merge.set id:$id key:inquiry input_dir:%%www/tmp/${session}  >> %%www/tmp/${session}/result
  fi
fi

# result check
updated_id=$(cat %%www/tmp/${session}/result | grep "^successfully set" | $AWK -F "id:" '{print $2}' | $SED '/^$/d' | sort | uniq)

# set message
if [ "$updated_id" ];then

  if [ "$id" = "new" ];then
    echo "<h2>SUCCESSFULLY SUBMITTED</h2>" > %%www/tmp/${session}/message
    echo "<a href=\"./inquiry?req=get&id=${updated_id}\"><p><b>YOUR LINK</b></p></a>" >> %%www/tmp/${session}/message
  else
    # redirect to the page
    echo "<meta http-equiv=\"refresh\" content=\"0; url=./inquiry?id=$id&req=get\">"
  fi
else
  echo "<h2>Failed, something is wrong. please contact to your web admin</h2>" > %%www/tmp/${session}/message
fi

# -----------------
# render HTML
# -----------------

cat %%www/def/inquiry_set.html.def | $SED -r "s/^( *)</</1" \
| $SED "/%%message/r %%www/tmp/${session}/message" \
| $SED "s/%%message/${message}/g"

if [ "$session" ];then
  rm -rf %%www/tmp/${session}
fi

exit 0
