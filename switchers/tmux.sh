#!/usr/bin/env bash
#/ Usage: tmux.sh NEW_PROJECT

set -e
set -x

env | grep PR_

[ "${1}" == "" ] && exit 0

current_file="${PR_STATE_PATH:?}/current"
last_file="${PR_STATE_PATH:?}/last"
last_project="$(<"${last_file}")"

# Tmux doesn't like . or : in session names as they represent window index or
# pane index.
new_session="${1//[.:]/_}"
last_session="${last_project//[.:]/_}"
current_session="$(tmux display-message -p '#S')"

echo "${1}" >> "${PR_STATE_PATH:?}/history"
current_project="$(<"${current_file}")"
echo "${1}" > "${current_file}"

if ! tmux has-session -t="${new_session}" 2> /dev/null; then
	tmux new-session -d -s "${new_session}" -c "${PR_BASE_PATH}/${1}"
fi

if [ "${TERM_PROGRAM}" == "tmux" ]; then
	if [ "${current_session}" !=  "${last_session}" ]; then
		echo "${current_project}" > "${last_file}"
	fi

	tmux switch-client -t="${new_session}"
else
	tmux attach-session -t="${new_session}"
fi

