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
    echo ''
    return
  fi
  local included_status=()
  local matched_globs=()
  local status_line
  for status_line in ${(f)status_lines}; do
    local matched_glob="$(_zg_get_matched_exclude_glob "${status_line}")"
    if [[ -z "${matched_glob}" ]]; then
      included_status+=("${status_line}")
    elif [[ ${matched_globs[(Ie)${matched_glob}]} -eq 0 ]]; then
      # Only globs which excluded at least one filepath are shown in the header, once each.
      matched_globs+=("${matched_glob}")
    fi
  done
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
    filepaths+=("$(_zg_escape_filepath "$(_zg_get_filepath_from_status "${status_line}")")")
  done
  echo "${(j: :)filepaths}"
}

function _zg_handle_worktrees {
  local worktrees=()
  local lines="$(git worktree list --porcelain)"
  for line in ${(f)lines}; do
    if [[ ${#line} -gt 0 ]] && [[ "${line}" = worktree* ]]; then
      local worktree="${line}"
      worktree="${worktree#worktree }"
      # Case: Path has glob-special characters. Escape the path.
      if [[ "${worktree}" = *[\[\]{}\ ]* ]]; then
        worktree="\"${worktree}\""
      fi
      worktrees+=("${worktree}")
    fi
  done
  local fzf_args=(--multi --bind 'ctrl-a:toggle-all')
  local selected_worktrees=($(echo -n "${(j:\n:)worktrees}" | fzf "${fzf_args[@]}"))
  echo "${(j: :)selected_worktrees}"
}

# HELPERS

## @param $1 Line.
## @stdout Line without ANSI escape sequences.
function _zg_strip_ansi {
  setopt local_options extendedglob
  echo "${1//$'\e\['[0-9;]#m}"
}

## @param $1 Line from `git status --short` with color.
## @stdout First glob in `ZG_STATUS_EXCLUDE_GLOBS` matching the line's filepath, else nothing.
function _zg_get_matched_exclude_glob {
  local filepath="$(_zg_get_filepath_from_status "$(_zg_strip_ansi "${1}")")"
  # Git wraps in double quotes a filepath with whitespace. Match against the bare filepath, so
  # the globs do not need to account for the quotes.
  if [[ "${filepath}" = \"*\" ]]; then
    filepath="${filepath[2,-2]}"
  fi
  local glob
  for glob in ${ZG_STATUS_EXCLUDE_GLOBS[@]}; do
    if [[ "${filepath}" = ${~glob} ]]; then
      echo "${glob}"
      return
    fi
  done
}

## @param $1 Line from `git status --short` without color.
## @stdout Filepath of the line from `git status --short`.
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
  echo "${filepath}"
}

## @param $1 Filepath.
## @stdout Filepath safe to put in the zsh buffer.
function _zg_escape_filepath {
  local filepath="${1}"
  # Case: Filepath has glob-special characters. Escape the filepath. Git already escapes with
  # double quotes a filepath with whitespace, so no need to handle the whitespace case, nor to
  # add a second pair of double quotes to an already escaped filepath.
  if [[ "${filepath}" != \"*\" ]] && [[ "${filepath}" = *[\[\]{}]* ]]; then
    filepath="\"${filepath}\""
  fi
  echo "${filepath}"
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
