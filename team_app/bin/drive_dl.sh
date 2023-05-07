#!/bin/bash

# Target databox
databox=drive

# load small-shell conf
. %%www/descriptor/.small_shell_conf

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

if [ ! "$id" -a ! "$databox" -a ! "$pin" -a "$session" ];then
  echo "Content-Type: text/html"
  echo "error: parameter is not enough for donwloading data"
  exit 1
fi

# SET BASE_COMMAND
DATA_SHELL="${small_shell_path}/bin/DATA_shell session:$session pin:$pin app:team"

# load filename
filename=`$DATA_SHELL databox:$databox action:get key:file id:$id format:none app:team | $SED "s/file://g" | $AWK -F " #" '{print $1}'`

# -----------------
# render contents
# -----------------

echo "Content-Disposition: attachment; filename=\"$filename\""
echo "Content-Type: application/octet-stream"
echo ""
${small_shell_path}/bin/dl session:$session pin:$pin databox:$databox id:$id app:team

if [ "$session" ];then
  rm -rf %%www/tmp/${session}_log
fi

exit 0
