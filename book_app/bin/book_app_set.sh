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

# get book_id
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


if [ ! "$flag" = "error" ];then

  # update library.db
  $DATA_SHELL databox:library.db action:set id:$book_id key:status value:requested format:html_tag > ../tmp/$session/library.db.result

  # update issue.db
  $DATA_SHELL databox:issue.db \
  action:set id:new keys:book_name,date_from,date_to,user_name,E-mail input_dir:../tmp/$session format:html_tag > ../tmp/$session/issue.db.result

  # result check
  updated_id=`cat ../tmp/$session/issue.db.result | grep "^successfully set" | awk '{print $3}' | uniq`

  # check result
  if [ "$updated_id" ];then
    echo "<h2>REQUEST REGISTERED</h2>" > ../tmp/$session/result
    echo "<a href=\"./book_app?req=get&id=$updated_id\"><p><b>REQUEST LINK</b></p></a>" >> ../tmp/$session/result
 
    # insert issue id to library.db
    SERVER=`$META get.server`
    issue_link="http{%%%}//${SERVER}/cgi-bin/controller?session=%%session&pin=%%pin&databox=issue.db&req=get&id=$updated_id"

    $DATA_SHELL databox:library.db \
    action:set id:$book_id key:issue_link value:$issue_link format:html_tag >> ../tmp/$session/library.db.result

    # update issue.db status
    $DATA_SHELL databox:issue.db action:set id:$updated_id key:status value:waiting_approval format:html_tag > ../tmp/$session/issue.db.result

  else
    echo "<h2>something wrong, please contact to web admin</h2>" > ../tmp/$session/result
  fi

fi

# -----------------
# render HTML
# -----------------

cat ../descriptor/book_app_set.html.def | sed "s/^ *</</g" \
| sed "/%%result/r ../tmp/$session/result" \
| sed "/%%result/d"

if [ "$session" ];then
  rm -rf ../tmp/$session
fi

exit 0
