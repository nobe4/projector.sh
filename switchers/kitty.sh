#!/usr/bin/env bash
#/ Usage: kitty.sh NEW_PROJECT
#/
#/ Require the environment variables:
#/   PR_STATE_PATH
#/   PR_BASE_PATH

set -e

show_help() { grep ^#/ <"${0}" | cut -c4- ; }
[ "${*}" == "-h" ] && show_help && exit 0

[ "${1}" == "" ] && exit 0

current_file="${PR_STATE_PATH:?}/current"
current_project="$(<"${current_file}")"

echo "${1}" >> "${PR_STATE_PATH:?}/history"
echo "${1}" > "${current_file}"

last_file="${PR_STATE_PATH:?}/last"
last_project="$(<"${last_file}")"

if [ "${current_project}" !=  "${last_project}" ]; then
	echo "${current_project}" > "${last_file}"
fi

(
	kitty --directory "${PR_BASE_PATH}/${1}" --start-as maximized
) &
