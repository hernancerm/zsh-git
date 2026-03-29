# zsh-git

Zsh + [fzf](https://github.com/junegunn/fzf) + git

## Usage

- <kbd>ctrl+g s</kbd> Add status files to the Zsh buffer (example use case: `git add <ctrl+g s>`).
- <kbd>ctrl+g h</kbd> Add the HEAD to the Zhs buffer (example use case: `git commit -m '<ctrl+g h>`).

## Installation

### Without a plugin manager

1. Install [fzf](https://github.com/junegunn/fzf).

2. Clone the zsh-git repository by executing the below command:

    ```text
    git clone 'https://github.com/hernancerm/zsh-git.git' \
      "${HOME}/.zsh-git/zsh-git"
    ```

3. Place the below snippet at the end of your file `~/.zshrc`:

    ```text
    source "${HOME}/.zsh-git/zsh-git/git.plugin.zsh"
    zg_setup_widget
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

    <kbd>ctrl+g</kbd> is set up inside the ZVM function below. Do not call
    `zg_setup_widget` when integrating with ZVM. Use:

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
<td><code>ZG_KEYBIND_START</code></td>
<td>
<a href="https://github.com/rothgar/mastering-zsh/blob/master/docs/helpers/bindkey.md">
Key binding</a></td><td><code>^g</code> (<kbd>ctrl+g</kbd>)</td>
<td>
Start fzf.
</td>
</tr>
</tbody>
</table>

## Similar projects

- <https://github.com/junegunn/fzf-git.sh>
