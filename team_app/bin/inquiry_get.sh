#!/bin/bash

# load small-shell conf
. %%www/descriptor/.small_shell_conf

# load query string param
for param in $(echo $@)
do

  if [[ $param == session:* ]]; then
    session=$(echo "$param" | $AWK -F":" '{print $2}')
  fi

  if [[ $param == pin:* ]]; then
    pin=$(echo "$param" | $AWK -F":" '{print $2}')
  fi

  if [[ $param == user_name:* ]]; then
    user_name=$(echo "$param" | $AWK -F":" '{print $2}')
  fi

  if [[ $param == id:* ]]; then
    id=$(echo "$param" | $AWK -F":" '{print $2}')
  fi

done

if [ ! "$id"  ];then
  id="new"
fi

if [ ! -d %%www/tmp/${session} ];then
  mkdir %%www/tmp/${session}
fi

# SET BASE_COMMAND
META="${small_shell_path}/bin/meta"
DATA_SHELL="${small_shell_path}/bin/DATA_shell session:$session pin:$pin app:inquiry"

if [ $id = "new" ];then

  # gen read/write form #new
  $DATA_SHELL databox:inquiries action:get id:$id keys:user_name,email,type,inquiry format:html_tag > %%www/tmp/${session}/dataset

else

  # gen read only contents
  #$DATA_SHELL databox:inquiries action:get id:$id keys:user_name,email,type format:none > %%www/tmp/${session}/dataset.0.1
  #cat %%www/tmp/${session}/dataset.0.1 | $SED "s/^/<li><label>/g" | $SED "s/:/<\/label><p>/g" | $SED "s/$/<\/p><\/li>/g" \
  #| $SED "s/<p><\/p>/<p>-<\/p>/g" >> %%www/tmp/${session}/dataset

  # gen interactive contents
  $DATA_SHELL databox:inquiries action:merge.get id:$id key:inquiry >> %%www/tmp/${session}/dataset
  name=$($DATA_SHELL databox:inquiries action:get id:$id key:user_name format:none | $AWK -F ":" '{print $2}')
  email=$($DATA_SHELL databox:inquiries action:get id:$id key:email format:none)
  type=$($DATA_SHELL databox:inquiries action:get id:$id key:type format:none)
  log=$($DATA_SHELL databox:inquiries action:get type:log id:$id format:none | head -1)

  # gen create history
  echo "<p>$log</p>" > %%www/tmp/${session}/history
  echo "<p>user:$name</p>" >> %%www/tmp/${session}/history
  echo "<p>$email</p>" >> %%www/tmp/${session}/history
  echo "<p>$type</p>" >> %%www/tmp/${session}/history

fi

# error check
error_chk=$(cat %%www/tmp/${session}/dataset | grep "^error:")

# render HTML
if [ "$error_chk" ];then
  cat %%www/descriptor/inquiry_get_err.html.def | $SED -r "s/^( *)</</1" \
  | $SED "s/%%id/${id}/g" \
  | $SED "s/%%params/session=${session}\&pin=${pin}/g"
elif [ "$id" = "new" ];then
  cat %%www/descriptor/inquiry_get_new.html.def | $SED -r "s/^( *)</</1" \
  | $SED "/%%dataset/r %%www/tmp/${session}/dataset" \
  | $SED "s/%%dataset//g"\
  | $SED "s/%%id/${id}/g" \
  | $SED "s/%%params/session=${session}\&pin=${pin}/g"
else
  cat %%www/descriptor/inquiry_get.html.def | $SED -r "s/^( *)</</1" \
  | $SED "/%%dataset/r %%www/tmp/${session}/dataset" \
  | $SED "s/%%dataset//g"\
  | $SED "/%%history/r %%www/tmp/${session}/history" \
  | $SED "s/%%history//g"\
  | $SED "s/%%user_name/${name}/g"\
  | $SED "s/%%id/${id}/g" \
  | $SED "s/+MERGE /<\/pre><pre class=\"adm\">/g" \
  | $SED "s/%%params/session=${session}\&pin=${pin}/g"
fi

if [ "$session" ];then
  rm -rf %%www/tmp/${session}
fi

exit 0
