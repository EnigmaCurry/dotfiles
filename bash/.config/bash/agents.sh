export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/ssh-agent.socket"
if (! ssh-add -l 2>&1 | grep id_rsa > /dev/null); then
    ssh-add
fi
