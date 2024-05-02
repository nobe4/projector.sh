#!/usr/bin/env bash
#/ Usage: tmux.sh NEW_PROJECT
#/
#/ Require the environment variables:
#/   PR_STATE_PATH
#/   PR_BASE_PATH

set -e

unset FZF_DEFAULT_OPTS PR_SWITCHER

show_help() { grep ^#/ <"${0}" | cut -c4- ; }
[ "${*}" == "-h" ] && show_help && exit 0

[ "${1}" == "" ] && exit 0

current_file="${PR_STATE_PATH:?}/current"
current_project="$(<"${current_file}")"

echo "${1}" >> "${PR_STATE_PATH:?}/history"
echo "${1}" > "${current_file}"

# Tmux doesn't like . or : in session names as they represent window index or
# pane index.
new_session="${1//[.:]/_}"

if ! tmux has-session -t="${new_session}" 2> /dev/null; then
	tmux new-session -d -s "${new_session}" -c "${PR_BASE_PATH}/${1}"
fi

if [ "${TERM_PROGRAM}" != "tmux" ]; then
	tmux attach-session -t="${new_session}"
	exit $?
fi

last_file="${PR_STATE_PATH:?}/last"
last_project="$(<"${last_file}")"

if [ "${current_project}" !=  "${last_project}" ]; then
	echo "${current_project}" > "${last_file}"
fi

tmux switch-client -t="${new_session}"
