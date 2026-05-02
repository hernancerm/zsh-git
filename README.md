# zsh-git

zsh + [fzf](https://github.com/junegunn/fzf) + git

## Usage

After sourcing the plugin these keybinds are set:

- <kbd>Ctrl-g</kbd><kbd>Ctrl-s</kbd> Add status files to the zsh buffer.
  - <kbd>Ctrl-f</kbd> Includes excluded items (`zg_exclude_status`) in fzf's list.
  - <kbd>Ctrl-a</kbd> Toggles selecting all items from fzf's list.
- <kbd>Ctrl-g</kbd><kbd>Ctrl-w</kbd> Add worktree path to the zsh buffer.
  - <kbd>Ctrl-a</kbd> Toggles selecting all items from fzf's list.
- <kbd>Ctrl-g</kbd><kbd>Ctrl-h</kbd> Add the HEAD to the zsh buffer.

Usage examples:

```text
git add <Ctrl-g><Ctrl-s>
git push -u origin <Ctrl-g><Ctrl-h>
cd <Ctrl-g><Ctrl-w>
```

> [!WARNING]
> <kbd>Ctrl-g</kbd><kbd>Ctrl-s</kbd> does not work if flow control is enabled, `stty
> -ixon` disables flow control.

Tip: Set `zg_map_head` and use `zg-head-map` to map the HEAD before putting it in the zsh
buffer. Example:

```bash
## @stdin HEAD.
## @stdout Mapped HEAD.
function zg_map_head {
  local line
  read line
  [[ ${line} =~ ([A-Z]+-[0-9]+) ]] \
    # Jira ticket key, e.g., ABC-123.
    && echo "${match[1]}"
}
source "${HOME}/.zsh-git/zsh-git/git.plugin.zsh"
bindkey "^g^k" zg-head-map

# Use case:
# Prefix the ticket key to each commit message:
# $ git commit -m '<Ctrl-g><Ctrl-k>

# File: ~/.zshrc
```

Tip: Set `zg_exclude_status` so <kbd>Ctrl-g</kbd><kbd>Ctrl-s</kbd> displays specific files
as excluded. Example:

```bash
# Set as needed:

## @stdin `git status -s` line with ANSI escape codes.
## @stdout 1 to display line as excluded by `zg-status`.
function zg_exclude_status {
  local line
  read -r line
  [[ "${line}" == *Dockerfile* ]] \
    && echo 1
  [[ "${line}" == *Makefile* ]] \
    && echo 1
}

# Use case:
# Exclude from `git add` files modified for app startup purposes.
# $ git add <Ctrl-g><Ctrl-s>
```

## Installation

### Without a plugin manager

1. Install [fzf](https://github.com/junegunn/fzf).

2. Clone the zsh-git repository by executing the below command:

    ```bash
    git clone 'https://github.com/hernancerm/zsh-git.git' \
      "${HOME}/.zsh-git/zsh-git"
    ```

3. Source the plugin (also add command to your `~/.zshrc` to enable on future sessions):

    ```bash
    source "${HOME}/.zsh-git/zsh-git/git.plugin.zsh"
    ```

    OR: If you want to set custom keybinds then use:

    ```bash
    ZG_SET_KEYBINDS=0
    source "${HOME}/.zsh-git/zsh-git/git.plugin.zsh"
    bindkey "^g^s" zg-status
    bindkey "^g^w" zg-worktrees
    bindkey "^g^h" zg-head
    ```

    OR: If you use [jeffreytse/zsh-vi-mode](https://github.com/jeffreytse/zsh-vi-mode):

    ```bash
    ZG_SET_KEYBINDS=0
    source "${HOME}/.zsh-git/zsh-git/git.plugin.zsh"
    function zvm_after_init {
      zvm_define_widget zg-menu
      # ZVM does not handle chords well, prefer zg-menu.
      zvm_bindkey viins "^g" zg-menu
    }
    ```

### With a plugin manager

With [Sheldon](https://github.com/rossmacarthur/sheldon):

```toml
[plugins.zsh-git]
github = "hernancerm/zsh-git"

# File: ~/.config/sheldon/plugins.toml
```

```bash
# Source plugins.
eval "$(sheldon source)"

# File: ~/.zshrc
```

## Similar projects

- <https://github.com/junegunn/fzf-git.sh>
