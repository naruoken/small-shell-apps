#!/bin/bash

# Target databox and keys
databox=bookmarks
keys=all

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

  if [[ $param == page:* ]]; then
    page=`echo $param | awk -F":" '{print $2}'`
  fi

  # filter can be input both query string and post
  if [[ $param == table_command:* ]]; then
    table_command=`echo $param | awk -F":" '{print $2}'`
  fi

done

# load small-shell path
. ../descriptor/.small_shell_path

# SET BASE_COMMAND
META="sudo -u small-shell ${small_shell_path}/bin/meta"
DATA_SHELL="sudo -u small-shell ${small_shell_path}/bin/DATA_shell session:$session pin:$pin app:team"

if [ "$page" = "" ];then
  page=1
fi

# load post param
if [ -s ../tmp/$session/table_command ];then
  table_command=`cat ../tmp/$session/table_command`
fi

primary_key=`$META get.key:$databox{primary}`
sort_chk_post=`echo $table_command | grep "^sort "`
sort_chk_query_string=`echo $table_command | grep "^sort,"`

if [ "$sort_chk_post" -o "$sort_chk_query_string" ];then
  table_command=`echo $table_command | sed "s/ /,/g"`
  sort_option=`echo $table_command | sed "s/sort,//g" | awk -F "," '{print $1}'`
  sort_col=`echo $table_command  | sed "s/sort,//g" | awk -F "," '{print $2}'`
  if [ ! "$sort_col" ];then
    sort_col=$primary_key
  fi
else
  if [[ $table_command == *{*} ]]; then
    filter_key=`echo $table_command | awk -F "{" '{print $1}'`
    filter_word=`echo $table_command | awk -F "{" '{print $2}' | sed "s/}//g" | sed "s/%//g" | sed "s/_/{%%%%%%%}/g" | sed "s/\//{%%%%%}/g" \
    | sed "s/,/{%%%%%%}/g"  | sed "s/#/{%%%%%%%%%%%%%}/g" |  sed "s/\&/{%%%%}/g" | sed "s/:/{%%%}/g" | sed "s/　/ /g" | sed "s/ /,/g"`
    filter_table="$filter_key{$filter_word}"
  else
    filter_table=`echo $table_command  | sed "s/%//g" | sed "s/_/{%%%%%%%}/g" | sed "s/\//{%%%%%}/g" | sed "s/,/{%%%%%%}/g" \
    | sed "s/\[/{%%%%%%%%%%}/g" | sed "s/\]/{%%%%%%%%%%%}/g"| sed "s/(/{%%%%%%%%}/g" | sed "s/)/{%%%%%%%%%}/g" | sed "s/|/{%%%%%%%%%%%%}/g" \
    | sed "s/#/{%%%%%%%%%%%%%}/g" |  sed "s/\&/{%%%%}/g" | sed "s/:/{%%%}/g" | sed "s/　/ /g" | sed "s/ /,/g"`
  fi
fi

if [ ! -d ../tmp/$session ];then 
  mkdir ../tmp/$session
fi

# -----------------
#  Preprocedure
# -----------------
if [ "$filter_table" ];then
  line_num=`$DATA_SHELL databox:$databox command:show_all[filter=${filter_table}][keys=$keys] format:none | wc -l`

elif [ "$sort_col" ];then
  line_num=`$DATA_SHELL databox:$databox command:show_all[sort=${sort_option},${sort_col}] format:none | wc -l`

else
  line_num=`$META get.num:$databox`

fi

# calc pages
((pages = $line_num / 18))
adjustment=`echo "scale=6;${line_num}/18" | bc | awk -F "." '{print $2}'`
line_start=$page
((line_start = $page * 18 - 17))
((line_end = $line_start + 17))

if [ ! "$adjustment" = "000000" ];then
  ((pages += 1))
fi

#-----------------------
# gen %%table contents
#-----------------------
if [ "$filter_table" ];then
  $DATA_SHELL databox:$databox \
  command:show_all[line=$line_start-$line_end][keys=$keys][filter=${filter_table}] > ../tmp/$session/table &

elif [ "$sort_col" ];then
  $DATA_SHELL databox:$databox \
  command:show_all[line=$line_start-$line_end][keys=$keys][sort=${sort_option},${sort_col}] > ../tmp/$session/table &
else
  $DATA_SHELL databox:$databox command:show_all[line=$line_start-$line_end][keys=$keys] > ../tmp/$session/table &
fi

# gen %%tag contents
$META get.tag:bookmarks{$databox} > ../tmp/$session/tags
for tag in `cat ../tmp/$session/tags`
do
 echo "<p><a href=\"./team?%%params&req=table&table_command=$tag\">#$tag&nbsp;</a></p>" > ../tmp/$session/tag &
done

# gen %%page_link contents
../bin/bookmarks_page_links.sh $page $pages $table_command > ../tmp/$session/page_link &
wait

# error check
err_chk=`grep "error: there is no databox" ../tmp/$session/table`

if [ "$err_chk" ];then

  echo "<h2>Oops please define Dawtabox and keys in bookmarks_table.sh for generating table</h2>"
  if [ "$session" ];then
    rm -rf ../tmp/$session
  fi
  exit 1
fi

# -----------------
# render HTML
# -----------------
wait

if [ ! "$filter_table" ];then
  filter_table="-"
fi

if [ ! "$sort_col" ];then
  sort_command="ordered by latest update"
else
  sort_command="sort option:$sort_option col:$sort_col"
fi

if [ "$line_num" = 0 ];then
  if [ "$err_chk" = "" -a "$filter_table" = "-" -a ! "$sort_col" ];then
    echo "<h4><a href=\"./team?%%params&req=get&id=new\">+ ADD DATA</a></h4>" >> ../tmp/$session/table
    view=bookmarks_table.html.def
  elif [ "$sort_col" ];then
    echo "<h4>sort option $sort_option seems wrong</h4>" >> ../tmp/$session/table
    view=bookmarks_table.html.def
  else
    echo "<h4>NO DATA</h4>" >> ../tmp/$session/table
    view=bookmarks_table.html.def
  fi
else
  view=bookmarks_table.html.def
fi

cat ../descriptor/$view | sed "s/^ *</</g" \
| sed "/%%common_menu/r ../descriptor/common_parts/team_common_menu" \
| sed "/%%common_menu/d"\
| sed "/%%table/r ../tmp/$session/table" \
| sed "s/%%table//g"\
| sed "s/%%databox/$databox/g"\
| sed "/%%page_link/r ../tmp/$session/page_link" \
| sed "s/%%page_link//g"\
| sed "/%%tag/r ../tmp/$session/tag" \
| sed "s/%%tag//g"\
| sed "s/%%user/$user_name/g"\
| sed "s/%%num/$line_num/g"\
| sed "s/%%filter/$filter_table/g"\
| sed "s/%%sort/$sort_command/g"\
| sed "s/%%key/$primary_key/g"\
| sed "s/{%%%%%%%%%%%%%}/\#/g"\
| sed "s/{%%%%%%%%%%%%}/|/g"\
| sed "s/{%%%%%%%%%%%}/\]/g"\
| sed "s/{%%%%%%%%%%}/\[/g"\
| sed "s/{%%%%%%%%%}/)/g"\
| sed "s/{%%%%%%%%}/(/g"\
| sed "s/{%%%%%%%}/_/g"\
| sed "s/{%%%%%%}/,/g"\
| sed "s/{%%%%%}/\//g"\
| sed "s/{%%%%}/\&/g"\
| sed "s/{%%%}/:/g"\
| sed "s/%%params/subapp=bookmarks\&session=$session\&pin=$pin\&databox=$databox/g"


if [ "$session" ];then
  rm -rf ../tmp/$session
fi

exit 0