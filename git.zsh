# zsh-git -- Ease using Git in the command line.
# Homepage: <https://github.com/hernancerm/zsh-git>.

# Do not source this script multiple times.
command -v zg_version > /dev/null && return

# CONFIGURATION

function zg_version {
  echo '0.1.2-SNAPSHOT'
}

ZG_KEY_MAP_START="${ZG_KEY_MAP_START:-^g}"

# HANDLERS

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

# WIDGETS

function zg_widget {
  local menu="s -- status\nh -- HEAD"
  local fzf_pick="$(echo "${menu}" | fzf --query=^ --bind one:accept)"
  local handler_alias="${${(s: :)fzf_pick}[1]}"
  if [[ "${handler_alias}" = 'h' ]]; then
    LBUFFER+="$(_zg_handle_head)"
  elif [[ "${handler_alias}" = 's' ]]; then
    LBUFFER+="$(_zg_handle_status)"
  fi
  zle reset-prompt
}

# Standard widget setup.
function zg_setup_widget {
  zle -N zg_widget
  bindkey "${ZG_KEY_MAP_START}" zg_widget
}

# Setup widget as per zsh-vi-mode requirements.
# <https://github.com/jeffreytse/zsh-vi-mode/tree/master#custom-widgets-and-keybindings>.
function zg_zvm_setup_widget {
  zvm_define_widget zg_widget
  zvm_bindkey viins "${ZG_KEY_MAP_START}" zg_widget
}
