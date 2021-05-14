export EMACS_SERVER=$(basename $PWD)

if ! test -S /tmp/emacs$(id -u)/$EMACS_SERVER; then
  echo "$(tput setaf 2)~$(tput sgr0) Starting Emacs session $(tput setaf 7)$EMACS_SERVER$(tput sgr0)"
  emacs --daemon=$EMACS_SERVER
fi

# Rename first tab.
if test $(tmux display-message -p '#I') = "1"; then
  tmux rename-window "E:$EMACS_SERVER"
fi

e() { (test "$#" -eq 0) && emacsclient -s $EMACS_SERVER . || emacsclient -s $EMACS_SERVER $@ }
