# zsh-git

zsh + [fzf](https://github.com/junegunn/fzf) + git

## Usage

After sourcing the plugin these keybinds are set:

- <kbd>Ctrl-g</kbd><kbd>Ctrl-s</kbd> Add status files to the zsh buffer.
  - <kbd>Ctrl-f</kbd> Includes excluded items (`ZG_STATUS_EXCLUDE_GLOBS`) in fzf's list.
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

### Excluding files from `zg-status` (<kbd>Ctrl-g</kbd><kbd>Ctrl-s</kbd>)

Set `ZG_STATUS_EXCLUDE_GLOBS` so <kbd>Ctrl-g</kbd><kbd>Ctrl-s</kbd> leaves specific files
out of fzf's list. Each entry is a zsh glob matched against the filepath of a `git
status` entry. Only the globs which excluded at least one file are listed in fzf's header.
Press <kbd>Ctrl-f</kbd> to list the full `git status`. Example:

```bash
# Set as needed:

ZG_STATUS_EXCLUDE_GLOBS=(
  'Makefile'
  'Dockerfile'
  'notes \(1\).md'
  'vendor/*'
  '*.log'
)

# Use case:
# Exclude from `git add` files modified for app startup purposes.
# $ git add <Ctrl-g><Ctrl-s>
```

The matching is zsh pattern matching, not filename generation, so `*` crosses `/`:
`vendor/*` excludes `vendor/a/b.go` and `**` behaves the same as `*`. Besides `*`, these
characters are meaningful in a glob:

- `?` (any single character)
- `[abc]` and `[^abc]` (character classes)
- `<1-9>` (numeric range)
- `(a|b)` (alternation)

A filepath which contains any of them literally needs each one backslash-escaped, as in
the `notes \(1\).md` entry above. With `setopt extendedglob`, which zsh-git honors but
does not set, `#`, `##`, `^` and `~` become meaningful too and likewise need escaping.

#### Per directory autoloading of `ZG_STATUS_EXCLUDE_GLOBS`

Set `ZG_STATUS_EXCLUDE_GLOBS_AUTOLOAD=1` before sourcing the plugin to define the
exclusions per directory:

```bash
ZG_STATUS_EXCLUDE_GLOBS_AUTOLOAD=1
source "${HOME}/.zsh-git/zsh-git/git.plugin.zsh"

# File: ~/.zshrc
```

On each directory change, `ZG_STATUS_EXCLUDE_GLOBS` is reset and then set from the closest
`.ZG_STATUS_EXCLUDE_GLOBS` file. The lookup starts at the cwd and walks up the parent
dirs, stopping at `${HOME}` or `/`. The first file found wins; files higher up are not
merged in. When no file is found the parameter is left empty. With the autoload enabled, a
value assigned in `~/.zshrc` for `ZG_STATUS_EXCLUDE_GLOBS` is discarded on the first `cd`.

Each line of the `.ZG_STATUS_EXCLUDE_GLOBS` file is one entry of
`ZG_STATUS_EXCLUDE_GLOBS`, taken verbatim, with the same glob syntax described above.
Empty lines are dropped. There is no comment syntax, since `#` is a glob character under
`extendedglob`. Example contents of a `.ZG_STATUS_EXCLUDE_GLOBS` file placed at the root
of a repository:

```text
Makefile
Dockerfile
notes \(1\).md
vendor/*
*.log
```

I recommend adding `.ZG_STATUS_EXCLUDE_GLOBS` to your global `.gitignore`.

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
