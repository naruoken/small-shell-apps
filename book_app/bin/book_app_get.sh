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


# -----------------
# Exec command
# -----------------

# SET BASE_COMMAND
META="sudo -u small-shell ${small_shell_path}/bin/meta"
DATA_SHELL="sudo -u small-shell ${small_shell_path}/bin/DATA_shell session:$session pin:$pin"

if [ $id = "new" ];then

  # get data structure
  $META get.pdls:library.db{available} > ../tmp/$session/dataset
  $DATA_SHELL databox:issue.db action:get id:$id keys:user_name,email,date_from,date_to format:html_tag >> ../tmp/$session/dataset

else

  # get data with html format
  $DATA_SHELL databox:issue.db action:get id:$id keys:user_name,email,date_from,date_to,status,feedback format:none > ../tmp/$session/dataset.0.1

  # change htm format
  # key:value -> <li><label>$key</label><p>$value</p></li>
  cat ../tmp/$session/dataset.0.1 | sed "s/^/<li><label>/g" | sed "s/:/<\/label><p>/g" | sed "s/$/<\/p><\/li>/g" \
  | sed "s/<p><\/p>/<p>-<\/p>/g" > ../tmp/$session/dataset

  # get  history
  history=`$DATA_SHELL databox:issue.db action:get type:log id:$id format:none | head -1`

fi

# -----------------
# render HTML
# -----------------

if [ "$id" = "new" ];then
  cat ../descriptor/book_app_new.html.def | sed "s/^ *</</g" \
  | sed "/%%dataset/r ../tmp/$session/dataset" \
  | sed "s/%%dataset//g"\
  | sed "s/%%id/$id/g"
else
  cat ../descriptor/book_app_get.html.def | sed "s/^ *</</g" \
  | sed "/%%dataset/r ../tmp/$session/dataset" \
  | sed "s/%%dataset//g"\
  | sed "s/%%id/$id/g" \
  | sed "s/%%history/$history/g" 
fi

if [ "$session" ];then
  rm -rf ../tmp/$session
fi

exit 0
