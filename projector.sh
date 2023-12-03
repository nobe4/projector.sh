#!/usr/bin/env bash
#VERSION 0.0.1
#/ Usage: projector.sh [FLAGS] [COMMAND] [QUERY]
#/
#/ Select a local or remote project to switch to.
#/
#/ Local projects are folders in ${PR_BASE_PATH}.
#/ Remote projects are repositories you contributed to.
#/
#/ Status indications in the FZF search:
#/   - '-'  Last project
#/   - '*'  Recent project
#/   - '+'  Cloned project
#/   - '?'  Remote project
#/
#/ Requirements:
#/   - fzf
#/   - gh
#/
#/ Flags:
#/   -h|--help      Display this help.
#/   -v|--version   Display the version.
#/   -r|--refresh   Refresh cache.
#/
#/ Commands (default: 'switch'):
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
#/                          '{2}' corresponds to the selected project.
#/                          Value: '${FZF_DEFAULT_OPTS}'
#/
#/   PR_BASE_PATH           Path to the base folder.
#/                          Value: '${PR_BASE_PATH}'
#/
#/   PR_CACHE_TTL_DAYS      Number of days after which the cache needs to refresh.
#/                          Set to -1 to always refresh.
#/                          Value: '${PR_CACHE_TTL_DAYS}'
#/
#/   PR_STATE_PATH          Path to the state folder.
#/                          Uses XDG_STATE_HOME if set.
#/                          value: '${PR_STATE_PATH}'
#/
#/   PR_SWITCHER            Path or name of a script to use as the project
#/                          switcher. See switchers/tmux.sh for inspiration.

set -e

PR_BASE_PATH="${PR_BASE_PATH:-${HOME:?}/dev}"

PR_STATE_PATH="${PR_STATE_PATH:-${XDG_STATE_HOME:-${HOME:?}/.local/state}/pr}"
mkdir -p "${PR_STATE_PATH}"

# Don't touch the cache file to preserve last modification date.
touch "${PR_STATE_PATH:?}/"{current,history,ignored,last}

PR_CACHE_TTL_DAYS="${PR_CACHE_TTL_DAYS:-1}"

LAST_PROJECT="$(<"${PR_STATE_PATH}/last")"

show_help() {
	export \
		LAST_PROJECT \
		PR_BASE_PATH \
		PR_CACHE_TTL_DAYS \
		PR_STATE_PATH
	grep ^#/ <"${0}" | cut -c4- | envsubst
}

show_version(){
	grep ^#VERSION <"${0}" | cut -d' ' -f2
}

refresh_cache(){
	if [ -f "${PR_STATE_PATH}/cache" ]; then
		cache_age_in_days="$((( $(date +%s) - $(date -r "${PR_STATE_PATH}/cache" +%s)) / 86400))"
		[ "${cache_age_in_days}" -lt "${PR_CACHE_TTL_DAYS}" ] && return
	fi

	echo "Writing repo list to ${PR_STATE_PATH}/cache in the background" >&2
	sleep 0.5

	(
		# shellcheck disable=SC2016
		gh api graphql \
			--paginate \
			-f query='
				query($endCursor: String) {
					viewer {
						repositoriesContributedTo(first: 100, isLocked: false, includeUserRepositories: true, after: $endCursor) {
							nodes { nameWithOwner }
							pageInfo { hasNextPage endCursor }
						}
					}
				}
				' \
			--jq '.[].viewer.repositoriesContributedTo.nodes[].nameWithOwner' \
			> "${PR_STATE_PATH}/cache"
	) &
}

get_local_projects(){
	find "${PR_BASE_PATH}" -type d -maxdepth 2 -mindepth 2 \
		| sed "s#^${PR_BASE_PATH}/##" \
		| grep -v '^$' \
		| sort -u
}

get_projects(){
	echo "- ${LAST_PROJECT}"

	recent_projects="$(
		sort < "${PR_STATE_PATH}/history" \
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
	remote_projects="$(cat "${PR_STATE_PATH}/cache")"
	all_projects="$(echo -e "${remote_projects}" | sort -u)"

	ignored_projects="$(cat "${PR_STATE_PATH}/ignored")"
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
			| awk '{print $2}' \
		|| true # prevent fzf from failing on exit
}

clone_project(){
	project_path="${PR_BASE_PATH}/${1}"
	if [ ! -d "${project_path}" ]; then
		gh repo clone "${1}" "${project_path}"
	fi
}

switch_session(){
	if [ "${PR_SWITCHER}" == "" ]; then
		cd "${PR_BASE_PATH}/${1}"
		# This obviously isn't ideal, as it creates a new persistent shell.
		"${SHELL}"
	else
		export PR_BASE_PATH PR_STATE_PATH
		"${PR_SWITCHER}" "${1}"
	fi
}

while [ "${#}" -gt 0 ]; do
	case "${1}" in
		-h|--help) show_help && exit 0 ;;
		-v|--version) show_version && exit 0 ;;
		-r|--reload) PR_CACHE_TTL_DAYS=-1 ;;
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

COMMAND="${1:-"switch"}"
query="${*:2}"

case "${COMMAND}" in
	s|switch)
		project="$(select_project "$(get_projects)" "${query}" "Switch to ")"
		clone_project "${project}"
		switch_session "${project}"
		;;

	delete)
		project="$(select_project "$(get_local_projects)" "${query}" "Delete ")"
		rm -rf "${PR_BASE_PATH:?}/${project:?}"
		echo "${project} deleted locally"
		;;

	debug)
		find "${PR_STATE_PATH}" -type f \
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
