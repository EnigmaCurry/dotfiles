# If not running interactively, don't do anything
[[ $- != *i* ]] && return

source ~/.config/bash/terminal.sh
source ~/.config/bash/paths.sh
source ~/.config/bash/aliases.sh
source ~/.config/bash/agents.sh

if [ -f ~/.config/bash/aliases-private.sh ]; then
    source ~/.config/bash/aliases-private.sh
fi


