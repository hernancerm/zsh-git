# zsh-git

zsh + [fzf](https://github.com/junegunn/fzf) + git

## Usage

After sourcing the plugin these keybinds are created (given `ZG_SET_KEYBINDS=1` which is
default):

- <kbd>Ctrl-g</kbd><kbd>Ctrl-s</kbd> Add status files to the zsh buffer (example use case: `git add <Ctrl-g Ctrl-s>`).
- <kbd>Ctrl-g</kbd><kbd>Ctrl-h</kbd> Add the HEAD to the zsh buffer (example use case: `git commit -m '<Ctrl-g Ctrl-h>`).
- <kbd>Ctrl-g</kbd><kbd>Ctrl-w</kbd> Add the worktree path to the zsh buffer.

> [!WARNING]
> <kbd>Ctrl-g</kbd><kbd>Ctrl-s</kbd> does not work if flow control is enabled, `stty
> -ixon` disables flow control.


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
