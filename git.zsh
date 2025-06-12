# zsh-git -- Ease using Git in the command line.
# Homepage: <https://github.com/hernancerm/zsh-git>.

# Do not source this script multiple times.
command -v zg_version > /dev/null && return

# CONFIGURATION

function zg_version {
  echo '0.1.1-dev'
}

ZG_KEY_MAP_START="${ZG_KEY_MAP_START:-^g}"

# WIDGETS

function zg_widget {
  local menu=$(
cat<<'EOF'
d -- HEAD
s -- status
EOF
)
  local menu_pick="${${(s: :)$(echo "${menu}" | fzf --query=^ --bind one:accept)}[1]}"
  if [[ "${menu_pick}" = 'd' ]]; then
    local git_branch_name="$(git rev-parse --abbrev-ref HEAD 2> /dev/null)"
    LBUFFER+="${git_branch_name/HEAD/}"
  elif [[ "${menu_pick}" = 's' ]]; then
    local git_status_files="$(git -c 'color.status=always' status -su 2> /dev/null)"
    if [[ -n "${git_status_files}" ]]; then
      local git_status_selected_files=(${(f)"$(echo ${git_status_files} \
        | fzf --bind='ctrl-p:toggle-preview' --preview='git diff --color=always {2}' \
          --height='-1' --preview-window='down,75%,hidden' --multi --ansi)"})
      for (( i=1; i<=${#git_status_selected_files}; i++ )); do
        LBUFFER+="${${(s: :)${git_status_selected_files[${i}]}}[2]}"
        if [[ ${i} -lt ${#git_status_selected_files} ]]; then
          LBUFFER+=' '
        fi
      done
    fi
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
