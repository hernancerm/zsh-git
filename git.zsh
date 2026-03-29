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

# HELPERS

# Helpers are used by the handlers to keep functions reasonably sized and avoid code duplication.

function _zg_normalize_status_line {
  local filepath="${${(s: :)${1}}[@]:1}"
  # Case: RM, with R staged but M unstaged. Extract second filepath.
  if [[ "${filepath}" = *" -> "* ]]; then
    filepath="${filepath##* -> }"
  fi
  # Case: Filepath part has glob-special charactrs. Escape the filepath. Git already escapes with
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
  local menu="s -- status\nh -- HEAD"
  local fzf_pick="$(echo "${menu}" | fzf --query=^ --bind one:accept \
    --bind 'ctrl-s:change-query(^s)' \
    --bind 'ctrl-h:change-query(^h)')"
  local handler_alias="${${(s: :)fzf_pick}[1]}"
  local -A handler_alias_to_handler=(
    [s]='_zg_handle_status'
    [h]='_zg_handle_head'
  )
  LBUFFER+="$(${handler_alias_to_handler[${handler_alias}]})"
  zle reset-prompt
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
