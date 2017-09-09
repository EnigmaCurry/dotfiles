export GPG_TTY=$(tty)
eval `keychain -q --eval id_rsa`
