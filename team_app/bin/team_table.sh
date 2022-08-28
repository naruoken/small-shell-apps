#!/bin/bash

# Target databox and keys
databox=events
keys=all

# load small-shell conf
. ../descriptor/.small_shell_conf

# load query string param
for param in `echo $@`
do

  if [[ $param == session:* ]]; then
    session=`echo $param | $AWK -F":" '{print $2}'`
  fi

  if [[ $param == pin:* ]]; then
    pin=`echo $param | $AWK -F":" '{print $2}'`
  fi

  if [[ $param == user_name:* ]]; then
    user_name=`echo $param | $AWK -F":" '{print $2}'`
  fi

  if [[ $param == page:* ]]; then
    page=`echo $param | $AWK -F":" '{print $2}'`
  fi

  # filter can be input both query string and post
  if [[ $param == table_command:* ]]; then
    table_command=`echo $param | $AWK -F":" '{print $2}' | $SED "s/{%%space}/ /g"`
  fi

done

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
  table_command=`echo $table_command | $SED "s/ /,/g"`
  sort_option=`echo $table_command | $SED "s/sort,//g" | $AWK -F "," '{print $1}'`
  sort_col=`echo $table_command  | $SED "s/sort,//g" | $AWK -F "," '{print $2}'`
  if [ ! "$sort_col" ];then
    sort_col=$primary_key
  fi
else
  if [[ $table_command == *{*} ]]; then
    filter_key=`echo $table_command | $AWK -F "{" '{print $1}'`
    filter_word=`echo $table_command | $AWK -F "{" '{print $2}' | $SED "s/}//g" \
    | $SED "s/%/{%%%%%%%%%%%%%%%%}/g"\
    | $SED "s/'/{%%%%%%%%%%%%%%%%%}/g" \
    | $SED "s/*/{%%%%%%%%%%%%%%%}/g" \
    | $SED "s/\\\\$/{%%%%%%%%%%%%%%}/g" \
    | $SED "s/#/{%%%%%%%%%%%%%}/g" \
    | $SED "s/|/{%%%%%%%%%%%%}/g" \
    | $SED "s/\]/{%%%%%%%%%%%}/g" \
    | $SED "s/\[/{%%%%%%%%%%}/g" \
    | $SED "s/)/{%%%%%%%%%}/g" \
    | $SED "s/(/{%%%%%%%%}/g" \
    | $SED "s/_/{%%%%%%%}/g" \
    | $SED "s/\//{%%%%%}/g"  \
    | $SED "s/,/{%%%%%%}/g"  \
    | $SED "s/\&/{%%%%}/g" \
    | $SED "s/:/{%%%}/g" \
    | $SED "s/　/ /g" | $SED "s/ /,/g" \
    | $PHP -r "echo preg_quote(file_get_contents('php://stdin'));"`
    filter_table="$filter_key{$filter_word}"
  else
    filter_table=`echo $table_command  \
    | $SED "s/%/{%%%%%%%%%%%%%%%%}/g"\
    | $SED "s/'/{%%%%%%%%%%%%%%%%%}/g" \
    | $SED "s/*/{%%%%%%%%%%%%%%%}/g" \
    | $SED "s/\\\\$/{%%%%%%%%%%%%%%}/g" \
    | $SED "s/#/{%%%%%%%%%%%%%}/g" \
    | $SED "s/|/{%%%%%%%%%%%%}/g" \
    | $SED "s/\[/{%%%%%%%%%%}/g" \
    | $SED "s/)/{%%%%%%%%%}/g" \
    | $SED "s/(/{%%%%%%%%}/g" \
    | $SED "s/_/{%%%%%%%}/g" \
    | $SED "s/\//{%%%%%}/g"  \
    | $SED "s/,/{%%%%%%}/g"  \
    | $SED "s/\&/{%%%%}/g" \
    | $SED "s/:/{%%%}/g" \
    | $SED "s/　/ /g" | $SED "s/ /,/g" \
    | $PHP -r "echo preg_quote(file_get_contents('php://stdin'));"`
  fi
fi

if [ ! -d ../tmp/$session ];then 
  mkdir ../tmp/$session
fi

# -----------------
#  Preprocedure
# -----------------
if [ "$filter_table" ];then
  line_num=`$DATA_SHELL databox:$databox command:show_all[filter=${filter_table}][keys=$keys] format:none | wc -l | tr -d " "`

elif [ "$sort_col" ];then
  line_num=`$DATA_SHELL databox:$databox command:show_all[sort=${sort_option},${sort_col}] format:none | wc -l | tr -d " "`

else
  line_num=`$META get.num:$databox`

fi

# calc pages
((pages = $line_num / 18))
adjustment=`echo "scale=6;${line_num}/18" | bc | $AWK -F "." '{print $2}'`
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
$META get.tag:team{$databox} > ../tmp/$session/tags
for tag in `cat ../tmp/$session/tags`
do
 echo "<p><a href=\"./team?%%params&req=table&table_command=$tag\">#$tag&nbsp;</a></p>" > ../tmp/$session/tag &
done

# load permission
permission=`$META get.attr:team/$user_name{permission}`


# gen %%page_link contents
../bin/team_page_links.sh $page $pages "$table_command" > ../tmp/$session/page_link &
wait

# error check
err_chk=`grep "error: there is no databox" ../tmp/$session/table`

if [ "$err_chk" ];then

  echo "<h2>Oops something must be wrong, please check  team_table.sh</h2>"
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

    view=team_table.html.def
    if [ ! "$permission" = "ro" ];then
      echo "<h4><a href=\"./team?%%params&req=get&id=new\">+ ADD DATA</a></h4>" >> ../tmp/$session/table
    else
      echo "<h4>NO DATA</h4>" >> ../tmp/$session/table
    fi

  elif [ "$sort_col" ];then
    echo "<h4>sort option $sort_option seems wrong</h4>" >> ../tmp/$session/table
    view=team_table.html.def
  else
    echo "<h4>NO DATA</h4>" >> ../tmp/$session/table
    view=team_table.html.def
  fi
else
  view=team_table.html.def
fi

cat ../descriptor/$view | $SED -r "s/^( *)</</1" \
| $SED "/%%common_menu/r ../descriptor/common_parts/team_common_menu" \
| $SED "/%%common_menu/d"\
| $SED "/%%table_menu/r ../descriptor/common_parts/table_menu_${permission}" \
| $SED "/%%table_menu/d"\
| $SED "/%%table/r ../tmp/$session/table" \
| $SED "s/%%table//g"\
| $SED "s/events/$databox/g"\
| $SED "/%%page_link/r ../tmp/$session/page_link" \
| $SED "s/%%page_link//g"\
| $SED "/%%tag/r ../tmp/$session/tag" \
| $SED "s/%%tag//g"\
| $SED "s/%%user/$user_name/g"\
| $SED "s/%%num/$line_num/g"\
| $SED "s/%%filter/$filter_table/g"\
| $SED "s/%%sort/$sort_command/g"\
| $SED "s/%%key/$primary_key/g"\
| $SED "s/{%%%%%%%%%%%%%%%%%}/'/g"\
| $SED "s/{%%%%%%%%%%%%%%%%}/%/g"\
| $SED "s/{%%%%%%%%%%%%%%%}/*/g"\
| $SED "s/{%%%%%%%%%%%%%%}/$/g"\
| $SED "s/{%%%%%%%%%%%%%}/\#/g"\
| $SED "s/{%%%%%%%%%%%%}/|/g"\
| $SED "s/{%%%%%%%%%%%}/\]/g"\
| $SED "s/{%%%%%%%%%%}/\[/g"\
| $SED "s/{%%%%%%%%%}/)/g"\
| $SED "s/{%%%%%%%%}/(/g"\
| $SED "s/{%%%%%%%}/_/g"\
| $SED "s/{%%%%%%}/,/g"\
| $SED "s/{%%%%%}/\//g"\
| $SED "s/{%%%%}/\&/g"\
| $SED "s/{%%%}/:/g"\
| $SED "s/.\/shell.app?/.\/team?/g"\
| $SED "s/%%session/session=$session\&pin=$pin/g" \
| $SED "s/%%params/session=$session\&pin=$pin/g" 

if [ "$session" ];then
  rm -rf ../tmp/$session
fi

exit 0
