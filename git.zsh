# Do not source this script multiple times.
command -v zg_version > /dev/null && return

# CONFIGURATION

function zg_version {
  echo '0.1.2-SNAPSHOT'
}

ZG_PREFIX="${ZG_PREFIX:-^g}"
ZG_SET_KEYBINDS="${ZG_SKIP_KEYBINDS:-1}"

# HANDLERS

# Each option from the main fzf menu should have a single corresponding handler that backs it. The
# handler is responsible for generating the text, as stdout, that is added to the zsh buffer.

function _zg_handle_head {
  local head="$(git rev-parse --abbrev-ref HEAD 2> /dev/null | sed 's/HEAD//')"
  if typeset -f zg_map_head > /dev/null; then
    echo "${head}" | zg_map_head
  else
    echo "${head}"
  fi
}

function _zg_handle_status {
  local status_lines="$(git -c 'color.status=always' status -su 2> /dev/null)"
  if [[ -z "${status_lines}" ]]; then
    echo ''
    return
  fi
  local excluded_status=()
  local included_status=()
  for status_line in ${(f)status_lines}; do
    if typeset -f zg_exclude_status > /dev/null; then
      if [[ "$(echo "${status_line}" | zg_exclude_status)" == 1 ]]; then
        excluded_status+=("${status_line}")
      else
        included_status+=("${status_line}")
      fi
    else
      included_status+=("${status_line}")
    fi
  done
  local header="$(printf '%s\n' "${excluded_status[@]}")"
  local fzf_args=(--multi --ansi)
  if [[ -n "${header}" ]]; then
    fzf_args+=(--header "${header}")
  fi
  local selected_status_lines=(${(f)"$(echo ${(j:\n:)included_status} \
    | fzf "${fzf_args[@]}")"})
  local filepaths=()
  for status_line in ${selected_status_lines}; do
    filepaths+=("$(_zg_get_filepath_from_status "${status_line}")")
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
  local selected_worktrees=($(echo -n "${(j:\n:)worktrees}" | fzf --multi))
  echo "${(j: :)selected_worktrees}"
}

# HELPERS

## @param $1 Line.
## @stdout Line without ANSI escape sequences.
function _zg_strip_ansi {
  setopt local_options extendedglob
  echo "${1//$'\e\['[0-9;]#m}"
}

## @param $1 Line from `git status --short` without color.
## @stdout Normalized line from `git status --short`.
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
  # Case: Filepath part has glob-special characters. Escape the filepath. Git already escapes with
  # double quotes a filepath with whitespace, so no need to handle the whitespace case.
  if [[ "${filepath}" = *[\[\]{}]* ]]; then
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
  LBUFFER+="$(_zg_handle_status)"
  zle .reset-prompt
}

function zg-worktrees {
  LBUFFER+="$(_zg_handle_worktrees)"
  zle .reset-prompt
}

function zg-head {
  LBUFFER+="$(_zg_handle_head)"
  zle .reset-prompt
}

zle -N zg-menu
zle -N zg-status
zle -N zg-worktrees
zle -N zg-head

# Set keybinds.

if [[ ZG_SET_KEYBINDS -eq 1 ]]; then
  bindkey "${ZG_PREFIX}^s" zg-status
  bindkey "${ZG_PREFIX}^w" zg-worktrees
  bindkey "${ZG_PREFIX}^h" zg-head
fi
