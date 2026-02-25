#!/bin/bash

for target in $(ls | grep -v renew.sh)
do
  cat $target | sed "s/Data.Num/Total/g" > /var/tmp/new
  cat /var/tmp/new > $target
done
