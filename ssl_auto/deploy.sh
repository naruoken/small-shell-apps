#!/bin/bash

WHOAMI=`whoami`
if [ ! "$WHOAMI" = "root" ];then
  echo "error: user must be root"
  exit 1
fi

if [ ! -d ./job ];then
  echo "please execute this script at `dirname $0`"
  exit 1
fi

if [ -f ./.configure ];then
  cluster_chk=`cat ./.configure | grep yes` 
  if [ "$cluster_chk" ];then
    ./script/cluster.sh
  else
    ./script/stand_alone.sh
  fi
else
  echo "please execute ./configure.sh first"
  exit 1
fi

exit 0
