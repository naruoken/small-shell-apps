#!/bin/bash

# Target databox and keys
databox=drive
keys=all

# define default num of line per page
num_of_line_per_page=12

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

  if [[ $param == user_name:* ]]; then
    user_name=`echo $param | $AWK -F":" '{print $2}'`
  fi

  if [[ $param == page:* ]]; then
    page=`echo $param | $AWK -F":" '{print $2}'`
  fi

  if [[ $param == line:* ]]; then
    line=`echo $param | $AWK -F":" '{print $2}'`
    if [ "$line" ];then
      num_of_line_per_page=$line
    fi
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
if [ -s %%www/tmp/$session/table_command ];then
  table_command=`cat %%www/tmp/$session/table_command`
fi

primary_key_label=`$META get.label:$databox{primary}`
sort_chk=`echo $table_command | grep -e "^sort " -e "^sort,"`
num_of_line_chk=`echo $table_command | grep -ie "^#line:" -e " #line:"`

if [ "$num_of_line_chk" ];then
  num_of_line_per_page=`echo $table_command | awk -F ":" '{print $2}'`
  table_command=`echo $table_command | $SED -r "s/ #(.*):(.*)//g" | $SED -r "s/^#(.*):(.*)//g"`
fi

if [ "$sort_chk" ];then
  table_command=`echo $table_command | $SED "s/ /,/g"`
  sort_option=`echo $table_command | $SED "s/sort,//g" | cut -f 1 -d ","`
  sort_label=`echo $table_command  | $SED "s/sort,//g" | cut -f 2- -d "," | $SED "s/,/{%%space}/g"`
  sort_col=`$META get.key:$databox{$sort_label}`

  if [ ! "$sort_col" ];then
    sort_label=" - "
    sort_col=`$META get.key:$databox{$primary_key_label}`
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

if [ ! -d %%www/tmp/$session ];then 
  mkdir %%www/tmp/$session
fi

if [ $num_of_line_per_page -lt 2 ];then
  num_of_line_per_page=12
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
((pages = $line_num / $num_of_line_per_page))
adjustment=`echo "scale=6;${line_num}/${num_of_line_per_page}" | bc | $AWK -F "." '{print $2}'`
((line_start = $page * ${num_of_line_per_page} - `expr ${num_of_line_per_page} - 1`))
((line_end = $line_start + `expr ${num_of_line_per_page} - 1`))

if [ ! "$adjustment" = "000000" ];then
  ((pages += 1))
fi

#-----------------------
# gen %%table contents
#-----------------------
if [ "$filter_table" ];then
  $DATA_SHELL databox:$databox \
  command:show_all[line=$line_start-$line_end][keys=$keys][filter=${filter_table}] > %%www/tmp/$session/table &

elif [ "$sort_col" ];then
  $DATA_SHELL databox:$databox \
  command:show_all[line=$line_start-$line_end][keys=$keys][sort=${sort_option},${sort_col}] > %%www/tmp/$session/table &
else
  $DATA_SHELL databox:$databox command:show_all[line=$line_start-$line_end][keys=$keys] > %%www/tmp/$session/table &
fi

# gen %%tag contents
$META get.tag:drive{$databox} > %%www/tmp/$session/tags
for tag in `cat %%www/tmp/$session/tags`
do
 echo "<p><a href=\"./team?%%params&req=table&table_command=$tag\">#$tag&nbsp;</a></p>" > %%www/tmp/$session/tag &
done

# load permission
if [ ! "$user_name" = "guest" ];then
  permission=`$META get.attr:team/$user_name{permission}`
else
  permission="ro"
fi

# gen %%page_link contents
%%www/bin/drive_page_links.sh $page $pages "$table_command" $num_of_line_per_page > %%www/tmp/$session/page_link &
wait

# error check
err_chk=`grep "error: there is no databox" %%www/tmp/$session/table`

if [ "$err_chk" ];then

  echo "<h2>Oops something must be wrong, please check drive_table.sh</h2>"
  if [ "$session" ];then
    rm -rf %%www/tmp/$session
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
  sort_command="sort option:$sort_option col:$sort_label"
fi

if [ "$line_num" = 0 ];then
  if [ "$err_chk" = "" -a "$filter_table" = "-" -a ! "$sort_col" ];then

    view=drive_table.html.def
    if [ ! "$permission" = "ro" ];then
      echo "<h4><a href=\"./team?&%%params&req=get&id=new\">+ ADD DATA</a></h4>" >> %%www/tmp/$session/table
    else
      echo "<h4>= NO DATA</h4>" >> %%www/tmp/$session/table
    fi

  elif [ "$sort_col" ];then
    echo "<h4>sort option $sort_option seems wrong</h4>" >> %%www/tmp/$session/table
    view=drive_table.html.def
  else
    echo "<h4>= NO DATA</h4>" >> %%www/tmp/$session/table
    view=drive_table.html.def
  fi
else
  view=drive_table.html.def
fi

cat %%www/descriptor/$view | $SED -r "s/^( *)</</1" \
| $SED "/%%common_menu/r %%www/descriptor/common_parts/team_common_menu" \
| $SED "/%%common_menu/d"\
| $SED "/%%table_menu/r %%www/descriptor/common_parts/table_menu_${permission}" \
| $SED "/%%table_menu/d"\
| $SED "/%%table/r %%www/tmp/$session/table" \
| $SED "s/%%table//g"\
| $SED "s/drive/$databox/g"\
| $SED "/%%page_link/r %%www/tmp/$session/page_link" \
| $SED "s/%%page_link//g"\
| $SED "/%%tag/r %%www/tmp/$session/tag" \
| $SED "s/%%tag//g"\
| $SED "s/%%user/$user_name/g"\
| $SED "s/%%num/$line_num/g"\
| $SED "s/%%filter/$filter_table/g"\
| $SED "s/%%sort/$sort_command/g"\
| $SED "s/%%key/$primary_key_label/g"\
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
| $SED "s/{%%space}/ /g"\
| $SED "s/.\/shell.app?/.\/team?/g"\
| $SED "s/%%session/session=$session\&pin=$pin/g" \
| $SED "s/%%params/subapp=drive\&session=$session\&pin=$pin\&databox=$databox/g"


if [ "$session" ];then
  rm -rf %%www/tmp/$session
fi

exit 0
