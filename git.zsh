# Do not source this script multiple times.
command -v zg_version > /dev/null && return

# CONFIGURATION

function zg_version {
  echo '0.1.2-SNAPSHOT'
}

ZG_KEYBIND_START="${ZG_KEYBIND_START:-^g}"

# HANDLERS

# Each option from the main fzf menu should have a single corresponding handler that backs it. The
# handler is responsible for generating the text, as stdout, that is added to the zsh buffer.

function _zg_handle_head {
  local branch_name="$(git rev-parse --abbrev-ref HEAD 2> /dev/null)"
  echo "${branch_name/HEAD/}"
}

function _zg_handle_status {
  local status_lines="$(git -c 'color.status=always' status -su 2> /dev/null)"
  if [[ -z "${status_lines}" ]]; then
    echo ''
    return
  fi
  local filepaths=()
  local selected_status_lines=(${(f)"$(echo ${status_lines} | fzf --multi --ansi)"})
  for status_line in ${selected_status_lines}; do
    filepaths+=("$(_zg_normalize_status_line "${status_line}")")
  done
  echo "${(j: :)filepaths}"
}

function _zg_handle_worktrees {
  local worktrees=()
  local lines=$(git worktree list --porcelain)
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

# Helpers are used by the handlers to keep functions reasonably sized and avoid code duplication.

## @param $1 Line.
## @stdout Line without ANSI escape sequences.
function _zg_strip_ansi {
  setopt local_options extendedglob
  echo "${1//$'\e\['[0-9;]#m}"
}

## @param $1 Line from `git status --short`. Structure: `XY<space><filepath>`.
## @stdout Normalized line from `git status --short`.
function _zg_normalize_status_line {
  local line="$(_zg_strip_ansi "${1}")"
  local index_status="${line[1]}"
  local filepath="${line[4,-1]}"
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

# WIDGET

# The widget is responsible for the main fzf menu and adding the handler stdout to the zsh buffer.

function _zg_widget {
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

# Standard widget setup.
function zg_setup_widget {
  zle -N _zg_widget
  bindkey "${ZG_KEYBIND_START}" _zg_widget
}

# Setup widget as per zsh-vi-mode requirements.
# <https://github.com/jeffreytse/zsh-vi-mode/tree/master#custom-widgets-and-keybindings>.
function zg_zvm_setup_widget {
  zvm_define_widget _zg_widget
  zvm_bindkey viins "${ZG_KEYBIND_START}" _zg_widget
}
