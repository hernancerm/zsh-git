# zsh-git -- Ease using Git in the command line.
# Homepage: <https://github.com/hernancerm/zsh-git>.

# https://zdharma-continuum.github.io/Zsh-100-Commits-Club/Zsh-Plugin-Standard.html
0="${ZERO:-${${0:#$ZSH_ARGZERO}:-${(%):-%N}}}"
0="${${(M)0:#/*}:-$PWD/$0}"

ZG_PATH="${0:h}"
source ${ZG_PATH}/git.zsh
