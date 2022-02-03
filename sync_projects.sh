#!/usr/bin/env bash
TOKEN=`cat ~/.config/toggl-argos-gnome-extension/config | jq --raw-output '.token'`

response=`curl -v -u "$TOKEN":api_token -X GET https://api.track.toggl.com/api/v8/me?with_related_data=true | jq '.data.projects'`

processed_response=`echo "$response" | jq '[ .[] | {(.id | tostring) : {name, hex_color}}] | add'`

echo "$processed_response" > ~/.config/toggl-argos-gnome-extension/projects_list
echo "$processed_response"
# echo "$RESPONSE"
