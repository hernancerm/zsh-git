# zsh-git

Zsh plugin leveraging [fzf](https://github.com/junegunn/fzf) to ease using Git in the
command line.

Demo showing listing status files and picking the Git HEAD:

[![asciicast](https://asciinema.org/a/716275.svg)](https://asciinema.org/a/716275)

## Usage

While on the shell, press <kbd>ctrl+g</kbd> to start fzf. Pick from one of the options with
<kbd>enter</kbd>.

## Installation

### Without a plugin manager

1. Install [fzf](https://github.com/junegunn/fzf), e.g., using
   [Homebrew](https://brew.sh/): `brew install fzf`.
2. Clone the zsh-git repository by executing the below command:

    ```text
    git clone 'https://github.com/hernancerm/zsh-git.git' \
      "${HOME}/.zsh-git/zsh-git"
    ```

3. Place the below snippet at the end of your file `~/.zshrc`:

    ```text
    # ZSH-GIT - Start - <https://github.com/hernancerm/zsh-git>.
    source "${HOME}/.zsh-git/zsh-git/git.plugin.zsh"
    zg_setup_widget
    # ZSH-GIT - End.
    ```

4. Start a new shell.

### With a plugin manager

If you feel comfortable with shell scripting and plan to install other Zsh plugins, like
[zsh-vi-mode](https://github.com/jeffreytse/zsh-vi-mode), I recommend you use a shell
plugin manager like [Sheldon](https://github.com/rossmacarthur/sheldon) for the
installation. Comparing this approach to the plugin-manager-less approach, the plugin
manager would be in charge of doing the git clone (step 2) and sourcing the plugin on
startup (line beginning with `source` from the snippet of step 3, you still need to call
`zg_setup_widget`).

## Integration with other Zsh plugins

- [jeffreytse/zsh-vi-mode](https://github.com/jeffreytse/zsh-vi-mode) (ZVM).
Binding <kbd>ctrl+g</kbd> is done inside a specific ZVM function, as below. Do not call
`zg_setup_widget` when integrating with ZVM.

    ```text
    function zvm_after_init {
      zg_zvm_setup_widget
    }
    ```

## Optional configuration

Optional configuration is provided through parameters.

<table>
<thead>
<tr>
<th>Zsh parameters</th><th>Allowed values</th>
<th>Default value</th><th>Description</th>
</tr>
</thead>
<tbody>
<tr>
<td><code>ZG_KEY_MAP_START</code></td>
<td>
<a href="https://github.com/rothgar/mastering-zsh/blob/master/docs/helpers/bindkey.md">
<code>bindkey</code> key map</a></td><td><code>^g</code></td>
<td>
Show menu options in fzf. Default: <kbd>ctrl+g</kbd>.
</td>
</tr>
</tbody>
</table>
