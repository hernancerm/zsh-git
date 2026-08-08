# Do not source this script multiple times.
command -v zg_version > /dev/null && return

# CONFIGURATION

function zg_version {
  echo '0.1.2-SNAPSHOT'
}

ZG_PREFIX="${ZG_PREFIX:-^g}"
ZG_SET_KEYBINDS="${ZG_SKIP_KEYBINDS:-1}"
ZG_STATUS_EXCLUDE="${ZG_STATUS_EXCLUDE:-0}"

typeset -g _zg_status_exclude_file
typeset -g _zg_status_match_repo
typeset -gA _zg_status_excluded_patterns

# HANDLERS

# Each option from the main fzf menu should have a single corresponding handler that backs it. The
# handler is responsible for generating the text, as stdout, that is added to the zsh buffer.

## @param [$1] 1 to map.
function _zg_handle_head {
  local head="$(git rev-parse --abbrev-ref HEAD 2> /dev/null | sed 's/HEAD//')"
  if [[ "${1}" = "1" ]] && typeset -f zg_map_head > /dev/null; then
    echo "${head}" | zg_map_head
  else
    echo "${head}"
  fi
}

function _zg_handle_status {
  _zg_find_status_exclude_file
  local cmd="git -c 'color.status=always' status -su 2> /dev/null"
  local status_lines="$(eval "${cmd}")"
  if [[ -z "${status_lines}" ]]; then
    print -r -- ''
    return
  fi
  local included_status=()
  local matched_patterns=()
  local status_line
  if [[ -z "${_zg_status_exclude_file}" ]]; then
    included_status=(${(f)status_lines})
  else
    local lines=(${(f)status_lines})
    _zg_find_match_repo
    # `git status` prints filepaths relative to `${PWD}`, which is what the zsh buffer needs, but
    # the match repository needs them relative to the root of the repository. `--show-prefix` is
    # the path from that root down to `${PWD}`, empty when `${PWD}` is the root itself.
    local prefix=''
    if [[ -n "${_zg_status_match_repo}" ]]; then
      prefix="$(git rev-parse --show-prefix 2> /dev/null)"
    fi
    # The filepaths are collected up front so that `git check-ignore` is run once for all of them
    # instead of once per line.
    local line_filepaths=()
    for status_line in ${lines[@]}; do
      _zg_strip_ansi "${status_line}"
      _zg_get_filepath_from_status "${REPLY}"
      if [[ -n "${prefix}" ]]; then
        # The filepath is below `${PWD}`, so prefixing gives the one relative to the root of the
        # repository. `:a` then resolves the `..` segments of a filepath which `git status` printed
        # as reaching above `${PWD}`. It is purely lexical, it does not touch the filesystem, and
        # the leading `/` is only there to keep it from prepending `${PWD}`.
        REPLY="${${:-/${prefix}${REPLY}}:a}"
        REPLY="${REPLY#/}"
      fi
      line_filepaths+=("${REPLY}")
    done
    _zg_load_excluded_patterns "${line_filepaths[@]}"
    local i pattern
    for i in {1..${#lines}}; do
      pattern="${_zg_status_excluded_patterns[${line_filepaths[i]}]}"
      if [[ -z "${pattern}" ]]; then
        included_status+=("${lines[i]}")
      elif [[ ${matched_patterns[(Ie)${pattern}]} -eq 0 ]]; then
        # Only patterns which excluded at least one filepath are shown in the header, once each.
        matched_patterns+=("${pattern}")
      fi
    done
  fi
  local fzf_args=(--multi --ansi --bind 'ctrl-a:toggle-all')
  local show_all_status="${cmd} | fzf --multi --ansi --bind ctrl-a:toggle-all --query={q}"
  # `become` instead of `reload` so fzf recomputes its height for the full status. This matters
  # when the user sets an adaptive height (`--height=~`); other height configs are unaffected.
  # There is no going back to the view with the exclusions.
  fzf_args+=(--bind "ctrl-f:become(${show_all_status})")
  if [[ ${#matched_patterns} -gt 0 ]]; then
    fzf_args+=(--header "${(F)matched_patterns}")
  fi
  # Case: Every filepath is excluded. Give fzf empty input instead of a single blank line.
  local fzf_input=''
  if [[ ${#included_status} -gt 0 ]]; then
    fzf_input="${(F)included_status}"$'\n'
  fi
  local selected_status_lines=(${(f)"$(printf '%s' "${fzf_input}" \
    | fzf "${fzf_args[@]}")"})
  local filepaths=()
  for status_line in ${selected_status_lines}; do
    _zg_get_filepath_from_status "${status_line}"
    _zg_escape_filepath "${REPLY}"
    filepaths+=("${REPLY}")
  done
  # `print -r` instead of `echo` so a backslash in a filepath is not processed as an escape.
  print -r -- "${(j: :)filepaths}"
}

function _zg_handle_worktrees {
  # `-z` is NUL delimited. `git worktree list --porcelain` prints paths raw, with no quoting at
  # all, so with the newline delimited output a path containing a newline splits one record over
  # two lines and the path is silently truncated.
  local records="$(git worktree list --porcelain -z 2> /dev/null)"
  local worktrees=()
  local record
  for record in ${(0)records}; do
    if [[ "${record}" = worktree\ * ]]; then
      worktrees+=("${record#worktree }")
    fi
  done
  if [[ ${#worktrees} -eq 0 ]]; then
    print -r -- ''
    return
  fi
  # NUL delimited on both sides too, so a path containing a newline stays a single fzf entry and
  # a single element of the selection.
  local fzf_args=(--multi --read0 --print0 --bind 'ctrl-a:toggle-all')
  # fzf shows the bare path; quoting is applied only to what is joined into the buffer, otherwise
  # the quotes would show up in the fzf list.
  local selected_worktrees=(${(0)"$(print -rN -- "${worktrees[@]}" | fzf "${fzf_args[@]}")"})
  local escaped_worktrees=()
  local worktree
  for worktree in ${selected_worktrees}; do
    _zg_escape_filepath "${worktree}"
    escaped_worktrees+=("${REPLY}")
  done
  # `print -r` instead of `echo` so a backslash in a path is not processed as an escape.
  print -r -- "${(j: :)escaped_worktrees}"
}

# HELPERS

# These helpers reply in `REPLY` instead of stdout. `zg-status` calls them once per line of
# `git status`, and a command substitution per line forks a subshell per line, which is slow on
# a repository with many changed files.

## @param $1 Line.
## @reply Line without ANSI escape sequences.
function _zg_strip_ansi {
  setopt local_options extendedglob
  REPLY="${1//$'\e\['[0-9;]#m}"
}

## @param $1 Line from `git status --short` without color.
## @reply Filepath of the line from `git status --short`.
function _zg_get_filepath_from_status {
  local index_status="${1[1]}"
  local filepath="${1[4,-1]}"
  # Case: R (rename) or C (copy). Filepath is "old -> new"; extract destination.
  if [[ "${index_status}" = [RC] ]]; then
    if [[ "${filepath[-1]}" = '"' ]]; then
      # Destination is git-quoted; internal `"` are escaped as `\"`.
      # `##* -> \"` strips to the opening delimiter; re-add the `"`.
      filepath="\"${filepath##* -> \"}"
    else
      # Destination is unquoted; take the last whitespace-free token.
      filepath="${filepath##* }"
    fi
  fi
  # Case: Git wrapped the filepath in double quotes, which it does when the filepath has
  # whitespace or characters it escapes C-style: `\t`, `\\`, `\"` and octal per byte for the
  # non-ASCII ones. Decode those escapes to get the filepath as it is on disk. Git quoting is
  # not zsh quoting, so it cannot be handed to the zsh buffer as-is.
  if [[ "${filepath}" = \"*\" ]]; then
    filepath="${filepath[2,-2]}"
    filepath="${(g:oe:)filepath}"
  fi
  REPLY="${filepath}"
}

## @param $1 Filepath.
## @reply Filepath quoted for the zsh buffer.
function _zg_escape_filepath {
  # Case: `!`. `(q+)` leaves it bare, and an unquoted `!` is history expansion in an interactive
  # shell: `zsh: event not found`. `(qq)` always single quotes, and history expansion is not
  # performed inside single quotes.
  if [[ "${1}" = *'!'* ]]; then
    REPLY="${(qq)1}"
    return
  fi
  # `(q+)` quotes only when needed and prefers single quotes, which keeps the buffer readable.
  REPLY="${(q+)1}"
}

# LOOKUP OF THE STATUS EXCLUSIONS

# The exclusions file is in gitignore syntax and is matched by `git check-ignore`, so its comment,
# escaping and pattern rules are git's, documented in `gitignore(5)`.

## Sets `_zg_status_exclude_file` to the closest `.zg_status_exclude` file. The lookup starts at
## `${PWD}` and walks up the parent directories, stopping at `${HOME}` when `${PWD}` is under it,
## else at `/`. The first file found wins; files higher up are not merged in.
function _zg_find_status_exclude_file {
  _zg_status_exclude_file=''
  if [[ ZG_STATUS_EXCLUDE -ne 1 ]]; then
    return
  fi
  local dir="${PWD}"
  while true; do
    if [[ -r "${dir}/.zg_status_exclude" ]]; then
      _zg_status_exclude_file="${dir}/.zg_status_exclude"
      return
    fi
    if [[ "${dir}" = "${HOME}" || "${dir}" = '/' ]]; then
      return
    fi
    dir="${dir:h}"
  done
}

## Sets `_zg_status_match_repo` to an empty repository kept for matching, else to nothing when it
## cannot be created.
##
## `git check-ignore` has to run inside a repository, and it reports the match of the highest
## precedence exclude source. `core.excludesFile`, the only source which can be pointed at an
## arbitrary path, is the lowest precedence one, so in the repository being worked on a filepath
## matched by both the exclusions file and a `.gitignore` is reported against the `.gitignore`.
## Matching in an empty repository instead leaves the exclusions file as the only source, so any
## filepath can be excluded, including one which is tracked and gitignored at the same time.
##
## The repository is only scaffolding for pattern matching: `git check-ignore` matches filepaths as
## text, so the filepaths need not exist there, and `--no-index` keeps it from reading the index.
## It stays empty and is created once. `init.templateDir` is emptied so that the template does not
## bring in an `info/exclude`, which would be a second exclude source.
function _zg_find_match_repo {
  local dir="${XDG_CACHE_HOME:-${HOME}/.cache}/zsh-git/match_repo"
  if [[ ! -e "${dir}/.git" ]]; then
    git -c init.templateDir= init -q "${dir}" 2> /dev/null
  fi
  _zg_status_match_repo=''
  if [[ -e "${dir}/.git" ]]; then
    _zg_status_match_repo="${dir}"
  fi
}

## Sets `_zg_status_excluded_patterns`, mapping each excluded filepath to the pattern of
## `_zg_status_exclude_file` which excluded it. Filepaths which are not excluded are absent.
## @param $@ Filepaths, relative to the root of the repository when `_zg_status_match_repo` is
## set, else relative to `${PWD}`.
function _zg_load_excluded_patterns {
  _zg_status_excluded_patterns=()
  # The exclusions file is fed to git as `core.excludesFile`, the one exclude source git reads
  # from an arbitrary path. `-C` runs the match repository when there is one; without it the
  # matching falls back to the repository being worked on, where a `.gitignore` takes precedence.
  #
  # `-z` is NUL delimited on both sides, so a filepath containing whitespace or a newline stays a
  # single record. `-v` prints `<source>`, `<line>`, `<pattern>` and `<filepath>` per match, and
  # only matches are printed, in the order the filepaths were given. `--no-index` so tracked
  # filepaths are checked too; they are the common case here, since `git status` reports untracked
  # filepaths only when they are not ignored in the first place.
  #
  # `-v` reports a match against a negative pattern (`!a.log`) too, which means the filepath is
  # explicitly not excluded, so those records are dropped below.
  local records="$(print -rN -- "${@}" \
    | git -C "${_zg_status_match_repo:-.}" -c "core.excludesFile=${_zg_status_exclude_file}" \
        check-ignore -z -v --no-index --stdin 2> /dev/null)"
  local fields=(${(0)records})
  local i
  for ((i = 1; i <= ${#fields}; i += 4)); do
    # Only the exclusions file may exclude from the list. In the match repository it is the only
    # source, so this drops nothing; in the fallback it drops the `.gitignore` matches.
    if [[ "${fields[i]}" != "${_zg_status_exclude_file}" || "${fields[i + 2]}" = '!'* ]]; then
      continue
    fi
    _zg_status_excluded_patterns[${fields[i + 3]}]="${fields[i + 2]}"
  done
}

# WIDGETS

function zg-menu {
  # Fixes fzf process 2 hiding zsh prompt.
  zle -I
  # Display main menu and handle selection.
  local menu="s -- status\nw -- worktrees\nh -- HEAD"
  local fzf_pick="$(echo "${menu}" | fzf --query=^ --bind one:accept)"
  local handler_alias="${${(s: :)fzf_pick}[1]}"
  local -A handler_alias_to_handler=(
    [s]='_zg_handle_status'
    [w]='_zg_handle_worktrees'
    [h]='_zg_handle_head'
  )
  LBUFFER+="$(${handler_alias_to_handler[${handler_alias}]})"
  zle .reset-prompt
}

function zg-status {
  # Fixes fzf process 2 hiding zsh prompt.
  zle -I
  LBUFFER+="$(_zg_handle_status)"
  zle .reset-prompt
}

function zg-worktrees {
  LBUFFER+="$(_zg_handle_worktrees)"
  zle .reset-prompt
}

function zg-head-map {
  LBUFFER+="$(_zg_handle_head 1)"
  zle .reset-prompt
}

function zg-head {
  LBUFFER+="$(_zg_handle_head)"
  zle .reset-prompt
}

zle -N zg-menu
zle -N zg-status
zle -N zg-worktrees
zle -N zg-head-map
zle -N zg-head

# Set keybinds.

if [[ ZG_SET_KEYBINDS -eq 1 ]]; then
  bindkey "${ZG_PREFIX}^s" zg-status
  bindkey "${ZG_PREFIX}^w" zg-worktrees
  bindkey "${ZG_PREFIX}^h" zg-head
fi
