# Do not source this script multiple times.
command -v zg_version > /dev/null && return

# CONFIGURATION

function zg_version {
  echo '0.1.2-SNAPSHOT'
}

ZG_PREFIX="${ZG_PREFIX:-^g}"
ZG_SET_KEYBINDS="${ZG_SKIP_KEYBINDS:-1}"

typeset -ga ZG_STATUS_EXCLUDE_GLOBS

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
  local cmd="git -c 'color.status=always' status -su 2> /dev/null"
  local status_lines="$(eval "${cmd}")"
  if [[ -z "${status_lines}" ]]; then
    print -r -- ''
    return
  fi
  local included_status=()
  local matched_globs=()
  local status_line
  if [[ ${#ZG_STATUS_EXCLUDE_GLOBS} -eq 0 ]]; then
    included_status=(${(f)status_lines})
  else
    for status_line in ${(f)status_lines}; do
      _zg_get_matched_exclude_glob "${status_line}"
      if [[ -z "${REPLY}" ]]; then
        included_status+=("${status_line}")
      elif [[ ${matched_globs[(Ie)${REPLY}]} -eq 0 ]]; then
        # Only globs which excluded at least one filepath are shown in the header, once each.
        matched_globs+=("${REPLY}")
      fi
    done
  fi
  local fzf_args=(--multi --ansi --bind 'ctrl-a:toggle-all')
  local show_all_status="${cmd} | fzf --multi --ansi --bind ctrl-a:toggle-all --query={q}"
  # `become` instead of `reload` so fzf recomputes its height for the full status. This matters
  # when the user sets an adaptive height (`--height=~`); other height configs are unaffected.
  # There is no going back to the view with the exclusions.
  fzf_args+=(--bind "ctrl-f:become(${show_all_status})")
  if [[ ${#matched_globs} -gt 0 ]]; then
    fzf_args+=(--header "${(F)matched_globs}")
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

## @param $1 Line from `git status --short` with color.
## @reply First glob in `ZG_STATUS_EXCLUDE_GLOBS` matching the line's filepath, else nothing.
function _zg_get_matched_exclude_glob {
  _zg_strip_ansi "${1}"
  _zg_get_filepath_from_status "${REPLY}"
  local filepath="${REPLY}"
  local glob
  for glob in ${ZG_STATUS_EXCLUDE_GLOBS[@]}; do
    if [[ "${filepath}" = ${~glob} ]]; then
      REPLY="${glob}"
      return
    fi
  done
  REPLY=''
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
