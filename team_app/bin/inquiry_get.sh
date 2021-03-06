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
DATA_SHELL="sudo -u small-shell ${small_shell_path}/bin/DATA_shell session:$session pin:$pin app:inquiry"

if [ $id = "new" ];then

  # gen reqd/write form #new
  $DATA_SHELL databox:inquiries action:get id:$id keys:user_name,email,type,inquiry format:html_tag > ../tmp/$session/dataset

else

  # gen read only contents
  #$DATA_SHELL databox:inquiries action:get id:$id keys:user_name,email,type format:none > ../tmp/$session/dataset.0.1
  #cat ../tmp/$session/dataset.0.1 | sed "s/^/<li><label>/g" | sed "s/:/<\/label><p>/g" | sed "s/$/<\/p><\/li>/g" \
  #| sed "s/<p><\/p>/<p>-<\/p>/g" >> ../tmp/$session/dataset

  # gen interactive contents
  $DATA_SHELL databox:inquiries action:merge.get id:$id key:inquiry >> ../tmp/$session/dataset
  name=`$DATA_SHELL databox:inquiries action:get id:$id key:user_name format:none | awk -F ":" '{print $2}'`
  email=`$DATA_SHELL databox:inquiries action:get id:$id key:email format:none`
  type=`$DATA_SHELL databox:inquiries action:get id:$id key:type format:none`
  log=`$DATA_SHELL databox:inquiries action:get type:log id:$id format:none | head -1`

  # gen create history
  echo "<p>$log</p>" > ../tmp/$session/history
  echo "<p>user:$name</p>" >> ../tmp/$session/history
  echo "<p>$email</p>" >> ../tmp/$session/history
  echo "<p>$type</p>" >> ../tmp/$session/history

fi

# error check
error_chk=`cat ../tmp/$session/dataset | grep "^error:"`

# render HTML
if [ "$error_chk" ];then
  cat ../descriptor/inquiry_get_err.html.def | sed -r "s/^( *)</</1" \
  | sed "s/%%id/$id/g" \
  | sed "s/%%params/session=$session\&pin=$pin/g"
elif [ "$id" = "new" ];then
  cat ../descriptor/inquiry_get_new.html.def | sed -r "s/^( *)</</1" \
  | sed "/%%dataset/r ../tmp/$session/dataset" \
  | sed "s/%%dataset//g"\
  | sed "s/%%id/$id/g" \
  | sed "s/%%params/session=$session\&pin=$pin/g"
else
  cat ../descriptor/inquiry_get.html.def | sed -r "s/^( *)</</1" \
  | sed "/%%dataset/r ../tmp/$session/dataset" \
  | sed "s/%%dataset//g"\
  | sed "/%%history/r ../tmp/$session/history" \
  | sed "s/%%history//g"\
  | sed "s/%%user_name/$name/g"\
  | sed "s/%%id/$id/g" \
  | sed "s/+MERGE /<\/pre><pre class=\"adm\">/g" \
  | sed "s/%%params/session=$session\&pin=$pin/g"
fi

if [ "$session" ];then
  rm -rf ../tmp/$session
fi

exit 0
