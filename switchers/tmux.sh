#!/usr/bin/env bash
#/ Usage: tmux.sh NEW_PROJECT

update_last(){
	current_session="$(tmux display-message -p '#S')"

	[ "${current_session}" == "${LAST_PROJECT//[.:]/_}" ] && return
	echo "${1}" > "${LAST_FILE_PATH}"
}

[ "${1}" == "" ] && exit 0

echo "${1}" >> "${HISTORY_FILE_PATH}"
current_project="$(<"${CURRENT_FILE_PATH}")"
echo "${1}" > "${CURRENT_FILE_PATH}"

# Tmux doesn't like . or : in session names as they represent window index or
# pane index.
session_name="${1//[.:]/_}"

if ! tmux has-session -t="${session_name}" 2> /dev/null; then
	tmux new-session -d -s "${session_name}" -c "${BASE_PATH}/${1}"
fi

if [ "${TERM_PROGRAM}" = "tmux" ]; then
	update_last "${current_project}"
	tmux switch-client -t="${session_name}"
else
	tmux attach-session -t="${session_name}"
fi

