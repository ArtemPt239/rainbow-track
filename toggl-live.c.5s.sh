#!/bin/bash

TOKEN=`cat ~/.config/toggl-argos-gnome-extension/config | jq --raw-output '.token'`
PROJECTS_LIST_PATH=~/.config/toggl-argos-gnome-extension/projects_list

PROJECTS_LIST=`cat "$PROJECTS_LIST_PATH"`

response=`curl -v -u "$TOKEN":api_token -X GET https://api.track.toggl.com/api/v8/time_entries/current`

# Parsing the response
get_name_by_pid () {
  jq --raw-output '."'"$1"'".name' <<< "$PROJECTS_LIST"
}
get_hex_color_by_pid () {
  jq '."'"$1"'".hex_color' <<< "$PROJECTS_LIST"
}


data=`echo "$response" | jq '.data'`
pid=`echo "$data" | jq '.pid'`
name=$(get_name_by_pid $pid)
hex_color=$(get_hex_color_by_pid $pid)
duration_secs=$(expr $(date +%s) +  $(echo $data | jq '.duration'))
duration=`printf '%d:%02d:%02d' $((duration_secs/3600)) $((duration_secs%3600/60)) $((duration_secs%60))`

# Table lights
python ~/Scripts/home/toggle_white_table_light.py -c `echo "$hex_color" | sed -E 's/#|"//g'`

# Managing dropdown list of projects
projects_array=`echo "$PROJECTS_LIST" | jq 'keys_unsorted' |  sed -E 's/\[|\]|"|,//g'`




# curl -v -u "$TOKEN":api_token \
# 	-H "Content-Type: application/json" \
# 	-d '{"time_entry":{"description":"Meeting with possible clients","tags":["billed"],"pid":123,"created_with":"curl"}}' \
# 	-X POST https://api.track.toggl.com/api/v8/time_entries/start


# Constructing dropdown with argos
# First span with a space is a workaround for making color work in later GNOME versions
echo "<span> </span>  <span foreground=$hex_color\> $name $duration</span>"

echo "---"

for project_id in $projects_array
do
  echo "<span> </span> <span foreground=$(get_hex_color_by_pid $project_id)\>$(get_name_by_pid $project_id)</span> | bash='curl -v -u $TOKEN:api_token\
  -H \"Content-Type: application/json\"\
  -d \"{\\\"time_entry\\\":{\\\"pid\\\":$project_id,\\\"created_with\\\":\\\"curl\\\"}}\"\
  -X POST https://api.track.toggl.com/api/v8/time_entries/start' \
  terminal=false"
done
