#!/usr/bin/env bash
#VERSION 0.0.1
#/ Usage: projector.sh [FLAGS] [COMMAND] [QUERY]
#/
#/ Select a local or remote project to switch to.
#/
#/ Local projects are folders in ${BASE_PATH}.
#/ Remote projects are repositories you contributed to.
#/
#/ Status indications in the FZF search:
#/   - '-'  Last project
#/   - '*'  Recent project
#/   - '+'  Cloned project
#/   - '?'  Remote project
#/
#/ Requirements:
#/   - tmux
#/   - fzf
#/   - gh
#/
#/ Flags:
#/   -h|--help      Display this help.
#/   -v|--version   Display the version.
#/   -r|--refresh   Refresh cache.
#/
#/ Commands (default: '${DEFAULT_COMMAND}'):
#/   debug          Print some debug information.
#/   delete         Delete the selected local project.
#/   -|last         Switch to last project ('${LAST_PROJECT}')
#/   n|new          Clone a project not in the contribution list.
#/                  Needs the 'owner/repo' or URL in QUERY.
#/   o|output       Output the name of the selected project.
#/   s|switch       Switch to selected project.
#/   w|web          Open selected project in your browser.
#/
#/ Environment variables:
#/   FZF_DEFAULT_OPTS       Respects this value for every FZF invocations.
#/                          Value: '${FZF_DEFAULT_OPTS}'
#/
#/   FZF_ADDITIONAL_OPTS    Append those to 'FZF_DEFAULT_OPTS'.
#/                          Value: '${FZF_ADDITIONAL_OPTS}'
#/
#/   PR_BASE_PATH           Path to the base folder.
#/                          Value: '${BASE_PATH}'
#/
#/   PR_CACHE_TTL_DAYS      Number of days after which the cache needs to refresh.
#/                          Set to -1 to always refresh.
#/                          Value: '${CACHE_TTL_DAYS}'
#/
#/   PR_STATE_PATH          Path to the state folder.
#/                          Uses XDG_STATE_HOME if set.
#/                          value: '${STATE_PATH}'
#/
#/   PR_FZF_PREVIEW_COMMAND FZF command for preview ({2} corresponds to the selected project)
#/                          Set to ' ' to disable.
#/                          Value: '${FZF_PREVIEW_COMMAND}'

set -e

BASE_PATH="${PR_BASE_PATH:-${HOME:?}/dev}"
CACHE_TTL_DAYS="${PR_CACHE_TTL_DAYS:-1}"

STATE_PATH="${PR_STATE_PATH:-${XDG_STATE_HOME:-${HOME:?}/.local/state}/pr}"
mkdir -p "${STATE_PATH}"

CACHE_FILE_PATH="${STATE_PATH:?}/cache"
FORCE_RELOAD_CACHE=0
# Don't touch the cache file to preserve last modification date.

LAST_FILE_PATH="${STATE_PATH:?}/last"
touch "${LAST_FILE_PATH}"
# shellcheck disable=SC2155
LAST_PROJECT="$(<"${LAST_FILE_PATH}")"

HISTORY_FILE_PATH="${STATE_PATH:?}/history"
touch "${HISTORY_FILE_PATH}"

IGNORED_FILE_PATH="${STATE_PATH:?}/ignored"
touch "${IGNORED_FILE_PATH}"

# shellcheck disable=SC2016
DEFAULT_FZF_PREVIEW_COMMAND='GH_FORCE_TTY=$FZF_PREVIEW_COLUMNS gh repo view {2}'
FZF_PREVIEW_COMMAND="${PR_FZF_PREVIEW_COMMAND:-${DEFAULT_FZF_PREVIEW_COMMAND}}"

DEFAULT_FZF_OPTS='
  --no-sort
  --info=inline
  --preview-window=up:85%:border-bottom:wrap
  --no-mouse
  --bind="ctrl-o:execute-silent(gh repo view --web {2})"
  --bind="ctrl-i:execute-silent(echo {2} >> '"${IGNORED_FILE_PATH}"')"
'
FZF_DEFAULT_OPTS="${FZF_DEFAULT_OPTS:-${DEFAULT_FZF_OPTS}} ${FZF_ADDITIONAL_OPTS}"

# shellcheck disable=SC2016
REPO_QUERY='
  query($endCursor: String) {
    viewer {
      repositoriesContributedTo(
        first: 100
        isLocked: false
        includeUserRepositories: true
        after: $endCursor
      ) {
        nodes { nameWithOwner }
        pageInfo { hasNextPage endCursor }
      }
    }
  }
'
REPO_EXTRACT='.[].viewer.repositoriesContributedTo.nodes[].nameWithOwner'

DEFAULT_COMMAND='switch'

show_help() {
	export \
		BASE_PATH \
		CACHE_TTL_DAYS \
		DEFAULT_COMMAND \
		FZF_DEFAULT_OPTS \
		FZF_PREVIEW_COMMAND \
		LAST_PROJECT \
		STATE_PATH
	grep ^#/ <"${0}" | cut -c4- | envsubst
}

show_version(){
	grep ^#VERSION <"${0}" | cut -d' ' -f2
}

refresh_cache(){
	if [ "${FORCE_RELOAD_CACHE}" == 0 ] && [ -f "${CACHE_FILE_PATH}" ]; then
		cache_age_in_days="$((( $(date +%s) - $(date -r "${CACHE_FILE_PATH}" +%s)) / 86400))"
		[ "${cache_age_in_days}" -lt "${CACHE_TTL_DAYS}" ] && return
	fi

	echo "Writing repo list to ${CACHE_FILE_PATH} in the background" >&2
	sleep 0.5

	(
		gh api graphql \
			--paginate \
			-f query="${REPO_QUERY}" \
			--jq "${REPO_EXTRACT}" \
			> "${CACHE_FILE_PATH}"
	) &
}

get_local_projects(){
	find "${BASE_PATH}" -type d -maxdepth 2 -mindepth 2 \
		| sed "s#^${BASE_PATH}/##" \
		| grep -v '^$' \
		| sort -u
}

get_projects(){
	echo "- ${LAST_PROJECT}"

	recent_projects="$(
		sort < "${HISTORY_FILE_PATH}" \
			| grep -v '^$' \
			| grep -v "${LAST_PROJECT}" \
			| uniq -c \
			| sort -nr \
			| sed 's/ *[0-9]* //'
	)"

	# shellcheck disable=SC2001
	echo "${recent_projects}" | sed 's/^/* /'

	local_projects="$(get_local_projects)"
	comm -23 \
		<(echo "${local_projects}") \
		<(echo -e "${recent_projects}\n${LAST_PROJECT}" | sort) \
		| grep -v '^$' \
		| sed 's/^/+ /'

	refresh_cache
	remote_projects="$(cat "${CACHE_FILE_PATH}")"
	all_projects="$(echo -e "${remote_projects}" | sort -u)"

	ignored_projects="$(cat "${IGNORED_FILE_PATH}")"
	projects_to_reject="$(echo -e "${ignored_projects}\n${recent_projects}\n${local_projects}" | sort -u)"

	comm -23 \
		<(echo "${all_projects}") \
		<(echo "${projects_to_reject}") \
		| grep -v '^$' \
		| sed 's/^/? /'
}

select_project(){
	echo "${1}" \
		| fzf \
			--select-1 \
			--nth=2 \
			--query="${2}" \
			--prompt="${3}" \
			--preview="${FZF_PREVIEW_COMMAND}" \
			| awk '{print $2}' \
		|| true # prevent fzf from failing on exit
}

clone_project(){
	project_path="${BASE_PATH}/${1}"
	if [ ! -d "${project_path}" ]; then
		gh repo clone "${1}" "${project_path}"
	fi
}

update_last(){
	current_session="$(tmux display-message -p '#S')"

	[ "${current_session}" == "${LAST_PROJECT//[.:]/_}" ] && return
	echo "${1}" > "${LAST_FILE_PATH}"
}

switch_session(){
	[ "${1}" == "" ] && return

	echo "${1}" >> "${HISTORY_FILE_PATH}"

	# Tmux doesn't like . or : in session names as they represent window index or
	# pane index.
	session_name="${1//[.:]/_}"

	if ! tmux has-session -t="${session_name}" 2> /dev/null; then
		tmux new-session -d -s "${session_name}" -c "${BASE_PATH}/${1}"
	fi

	if [ "${TERM_PROGRAM}" = "tmux" ]; then
		update_last "${1}"
		tmux switch-client -t="${session_name}"
	else
		tmux attach-session -t="${session_name}"
	fi
}

while [ "${#}" -gt 0 ]; do
	case "${1}" in
		-h|--help) show_help && exit 0 ;;
		-v|--version) show_version && exit 0 ;;
		-r|--reload) FORCE_RELOAD_CACHE=1 ;;
		-) break ;;
		-*)
			echo "Unknown flag '${1}'"
			show_help
			exit 1
			;;
		*)  break ;;
	esac

	shift 1
done

COMMAND="${1:-"${DEFAULT_COMMAND}"}"
query="${*:2}"

case "${COMMAND}" in
	s|switch)
		project="$(select_project "$(get_projects)" "${query}" "Switch to ")"
		clone_project "${project}"
		switch_session "${project}"
		;;

	delete)
		project="$(select_project "$(get_local_projects)" "${query}" "Delete ")"
		rm -rf "${BASE_PATH:?}/${project:?}"
		echo "${project} deleted locally"
		;;

	debug)
		find "${STATE_PATH}" -type f \
			-exec bash -c 'echo -e "$1\n$(cat "$1" | sort | uniq -c | sort -nr)\n"' \
			shell {} \; \
			| less
		;;

	-|last) switch_session "${LAST_PROJECT}" ;;

	n|new)
		project=$(gh repo view --json nameWithOwner --jq '.nameWithOwner' "${query}")
		clone_project "${project}"
		switch_session "${project}"
		;;

	o|output) select_project "$(get_projects)" "${query}" "Output " ;;

	w|web)
		project="$(select_project "$(get_projects)" "${query}" "Open ")"
		gh repo view --web "${project}"
		;;

	*)
		echo "Unknown command '${COMMAND}'"
		exit 1
		;;
esac
