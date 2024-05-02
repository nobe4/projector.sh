#!/usr/bin/env bash
#/ Usage: kitty.sh NEW_PROJECT
#/
#/ Require the environment variables:
#/   PR_STATE_PATH
#/   PR_BASE_PATH
#/
#/ Requires kitty to be configured with:
#/   allow_remote_control yes

set -e

unset FZF_DEFAULT_OPTS PR_SWITCHER

show_help() { grep ^#/ <"${0}" | cut -c4- ; }
[ "${*}" == "-h" ] && show_help && exit 0

[ "${1}" == "" ] && exit 0

history_file="${PR_STATE_PATH:?}/history"
current_file="${PR_STATE_PATH:?}/current"
current_project="$(<"${current_file}")"
last_file="${PR_STATE_PATH:?}/last"

echo "${1}" >> "${history_file}"
echo "${1}" > "${current_file}"

if [ "${current_project}" !=  "${last_project}" ]; then
	echo "${current_project}" > "${last_file}"
fi

# Focus the os-window by its title OR create a new one
kitty @ focus-window \
	--match="title:${1}" \
	2> /dev/null \
	||
kitty @ launch \
	--type=os-window \
	--no-response \
	--title="${1}" \
	--os-window-title="${1}" \
	--os-window-state=fullscreen \
	--cwd="${PR_BASE_PATH}/${1}"
