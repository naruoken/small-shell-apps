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

  # gen datalist of primary key value from library.db
  $META get.pdls:library.db{available} > ../tmp/$session/pdls_book_name

  # gen issue.db other values
  $DATA_SHELL databox:issue.db action:get id:$id keys:user_name,email,date_from,date_to format:html_tag > ../tmp/$session/dataset
 
  # insert comment
  comment="This is book issue request form, please select book and send request to us. if you have any issue please contact to XXXXX"

else

  # get book_id
  book_name=`$DATA_SHELL databox:issue.db action:get key:book_name id:$id format:none | awk -F ":" '{print $2}'`
  book_id=`$DATA_SHELL databox:library.db command:show_all[match=col1{$book_name}] format:json | jq .id | sed -s "s/\"//g"`

  # gen issue.db values
  $DATA_SHELL databox:issue.db action:get id:$id keys:user_name,email,book_name,date_from,date_to,status format:none > ../tmp/$session/dataset.0.1

  # change htm format
  # key:value -> <li><label>$key</label><p>$value</p></li>
  cat ../tmp/$session/dataset.0.1 | sed "s/^/<li><label>/g" | sed "s/:/<\/label><p>/g" | sed "s/$/<\/p><\/li>/g"  > ../tmp/$session/dataset

  # insert comment
  comment="Issue status is as following, you can pick up book once status become waiting_pickup"

fi


# -----------------
# render HTML
# -----------------

if [ "$id" = "new" ];then
  cat ../descriptor/book_app_new.html.def | sed "s/^ *</</g" \
  | sed "/%%pdls_book_name/r ../tmp/$session/pdls_book_name" \
  | sed "s/%%pdls_book_name//g"\
  | sed "/%%dataset/r ../tmp/$session/dataset" \
  | sed "s/%%dataset//g"\
  | sed "s/%%databox/$databox/g" \
  | sed "s/%%id/$id/g"\
  | sed "s/%%comment/$comment/g"\
  | sed "s/%%params/session=$session\&pin=$pin\&databox=$databox/g" 
else
  cat ../descriptor/book_app_get.html.def | sed "s/^ *</</g" \
  | sed "/%%dataset/r ../tmp/$session/dataset" \
  | sed "s/%%dataset//g"\
  | sed "s/%%id/$id/g"\
  | sed "s/%%comment/$comment/g"\
  | sed "s/%%params/session=$session\&pin=$pin\&databox=$databox/g" 
fi

if [ "$session" ];then
  rm -rf ../tmp/$session
fi
exit 0
