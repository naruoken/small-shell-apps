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

# -----------------
# Exec command
# -----------------

# BASE COMMAND
META="sudo -u small-shell ${small_shell_path}/bin/meta"
DATA_SHELL="sudo -u small-shell ${small_shell_path}/bin/DATA_shell session:$session pin:$pin"


# additional codes for book_app (get book_id)
book_name=`cat ../tmp/$session/book_name`
book_id=`$DATA_SHELL databox:library.db command:show_all[match=col1{$book_name}] format:json | jq .id | sed -s "s/\"//g"`

if [ ! "$book_id" ];then
  echo "<h1>It seems you set wrong book name</h1>"  > ../tmp/$session/result
  echo "<a href=\"./book_app?req=get\">BACK</a>" >> ../tmp/$session/result
  flag=error
else
  # check status
  status=`$DATA_SHELL databox:library.db action:get id:$book_id key:status format:none | sed "s/status://g"`

  if [ ! "$status" = "available" ];then
    echo "<h1>Book is already reserved</h2>"  > ../tmp/$session/result
    echo "<a href=\"./book_app?req=get\">BACK</a>" >> ../tmp/$session/result
    flag=error
  fi
fi


# push datas to databox
$DATA_SHELL databox:issue.db action:set id:$id keys:$keys input_dir:../tmp/$session > ../tmp/$session/result

# result check
updated_id=`cat ../tmp/$session/result | grep "^successfully set" | awk '{print $3}' | uniq`

# additional codes for book_app
$DATA_SHELL databox:issue.db action:set id:$updated_id key:status value:waiting_approval  >> ../tmp/$session/result
$DATA_SHELL databox:library.db action:set.force id:$book_id key:status value:requested >> ../tmp/$session/result
$DATA_SHELL databox:library.db action:set.force id:$book_id key:issue_id value:$updated_id >> ../tmp/$session/result

# set message
if [ "$updated_id" ];then
  echo "<h2>SUCCESSFULLY SUBMITTED</h2>" > ../tmp/$session/message
  echo "<a href=\"./book_app?req=get&id=$updated_id\"><p><b>YOUR LINK</b></p></a>" >> ../tmp/$session/message
else
  echo "<h2>Failed, something is wrong. please contact to your web admin</h2>" > ../tmp/$session/message
fi

# -----------------
# render HTML
# -----------------
cat ../descriptor/book_app_set.html.def | sed "s/^ *</</g" \
| sed "/%%message/r ../tmp/$session/message" \
| sed "s/%%message/$message/g"\
| sed "s/%%id/$id/g"

if [ "$session" ];then
  rm -rf ../tmp/$session
fi

exit 0
