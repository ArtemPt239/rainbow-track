#!/usr/bin/env bash
# Reading api token from config
TOKEN=`cat ~/.config/toggl-argos-gnome-extension/config | jq --raw-output '.token'`


# Getting user data
response=`curl -v -u "$TOKEN":api_token -X GET https://api.track.toggl.com/api/v8/me?with_related_data=true`


# Building projects list
projects_list=`echo "$response"  | jq '.data.projects' | jq '[ .[] | {(.id | tostring) : {name, hex_color}}] | add'`

echo "$projects_list" > ~/.config/toggl-argos-gnome-extension/projects_list
echo "$projects_list"


# Building recent descriptions
tags_list=`echo "$response"  | jq '.data.tags' | jq '[ .[] | {(.id | tostring) : {name}}] | add'`

echo "$tags_list" > ~/.config/toggl-argos-gnome-extension/tags_list
echo "$tags_list"
