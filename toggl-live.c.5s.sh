#!/bin/bash
API_URL='https://api.track.toggl.com/api/v8'
CONFIG_DIR_PATH=$( dirname -- "$( readlink -f -- "$0"; )" )
VARIABLES_PATH="$CONFIG_DIR_PATH"/var

TOKEN=`cat "$CONFIG_DIR_PATH"/config | jq --raw-output '.token'`
projects_list=`cat "$VARIABLES_PATH"/projects_list`
if [ $? -ne 0 ]
then
  bash "$CONFIG_DIR_PATH/sync_projects.sh"
fi
tags_list=`cat "$VARIABLES_PATH"/tags_list`
selected_tags=`cat "$VARIABLES_PATH"/selected_tags`


response=`curl -v -u "$TOKEN":api_token -X GET "$API_URL"/time_entries/current`
curl_exit_code=$?

if [ $curl_exit_code -ne 0 ]
then
  echo "No internet"
  exit 0
fi

# Parsing the response
get_name_by_pid () {
  jq --raw-output '."'"$1"'".name' <<< "$projects_list"
}
get_hex_color_by_pid () {
  jq '."'"$1"'".hex_color' <<< "$projects_list"
}
get_name_by_pid () {
  jq --raw-output '."'"$1"'".name' <<< "$projects_list"
}



data=`echo "$response" | jq '.data'`

time_entry_id=`echo "$data" | jq '.id'`
pid=`echo "$data" | jq '.pid'`
description=`echo "$data" | jq --raw-output '.description'`
name=$(get_name_by_pid $pid)
hex_color=$(get_hex_color_by_pid $pid)
duration_secs=$(expr $(date +%s) +  $(echo $data | jq '.duration'))
duration=`printf '%d:%02d:%02d' $((duration_secs/3600)) $((duration_secs%3600/60)) $((duration_secs%60))`

# echo Debug mode on
# echo "---"
# echo "Response: $response"
# echo "curl exit code: $curl_exit_code"
# echo data: "$data"
# echo time_entry_id: "$time_entry_id"
# echo pid: "$pid"
# echo description: "$description"
# echo name: "$name"
# echo hex_color: "$hex_color"
# echo duration_secs: "$duration_secs"
# echo duration: "$duration"

# Table lights
# python ~/Scripts/home/toggle_white_table_light.py -c `echo "$hex_color" | sed -E 's/#|"//g'`

# Managing dropdown list of projects
projects_array=`echo "$projects_list" | jq 'keys_unsorted' |  sed -E 's/\[|\]|"|,//g'`




# curl -v -u "$TOKEN":api_token \
# 	-H "Content-Type: application/json" \
# 	-d '{"time_entry":{"description":"Meeting with possible clients","tags":["billed"],"pid":123,"created_with":"curl"}}' \
# 	-X POST https://api.track.toggl.com/api/v8/time_entries/start


# Constructing dropdown with argos
# First span with a space is a workaround for making color work correctly in later GNOME versions


# Title
if [ "$data" = "null" ]
then
  echo "<span> </span>  <span> No timer is running </span>"
else
  if [ "$description" = "null" ]
  then
    echo "<span> </span>  <span foreground=$hex_color\> $name $duration </span>"
  else
    echo "<span> </span>  <span foreground=$hex_color\> $name $duration </span> ($description)"
  fi
fi

echo "---"


# Dropdown
echo "<span> </span> <span foreground=\"#ff0000\"\>Stop timer</span> |\
bash='curl -v -u $TOKEN:api_token \
-H \"Content-Type: application/json\" \
-X PUT $API_URL/time_entries/$time_entry_id/stop' \
terminal=false"

echo "---"


for project_id in $projects_array
do
  echo "<span> </span> <span foreground=$(get_hex_color_by_pid $project_id)\>$(get_name_by_pid $project_id)</span> |\
  bash='curl -v -u $TOKEN:api_token\
  -H \"Content-Type: application/json\"\
  -d \"{\\\"time_entry\\\":{\\\"pid\\\":$project_id,\\\"created_with\\\":\\\"curl\\\"}}\"\
  -X POST $API_URL/time_entries/start' \
  terminal=false \
  refresh=true"
done

echo "---"
echo "Settings"
echo "-- Refresh projects data | terminal=false bash='$CONFIG_DIR_PATH/sync_projects.sh'"
# echo "Add tag"
# for tag_id in tags_array
# do
#   # | terminal=false bash=''"
#
# done
