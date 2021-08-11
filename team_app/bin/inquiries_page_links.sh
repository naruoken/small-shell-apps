#!/bin/bash
page=$1
pages=$2
table_command=$3

if [ "$pages" = 1 ];then
 exit 0
fi

if [ $page -eq 10 ];then
   echo "<a href=\"./inquiries?%%params&req=table&page=1&table_command=$table_command\">1&nbsp;</a>"
fi
if [ $page -gt 10 ];then
   echo "<a href=\"./inquiries?%%params&req=table&page=1&table_command=$table_command\">1...&nbsp;</a>"
fi

((count = $page -8))
((upper_page = $page + 8))

while [ $count -le $upper_page -a $count -le $pages ]
do
  if [ ! $count -lt 1 -a ! $count -eq $page ];then
     echo "<a href=\"./inquiries?%%params&req=table&page=$count&table_command=$table_command\">${count}&nbsp;</a>"
     elif [ $count -eq $page ];then
     echo "<h3>${page}&nbsp;</h3>"
  fi
  ((count += 1))
done
  
((lower_page = $pages -8)) 
if [ $page -lt $lower_page ];then
  echo "<a href=\"./inquiries?%%params&page=$pages&req=table&table_command=$table_command\">...$pages</a>"
fi
