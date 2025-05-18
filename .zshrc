  set -e
  # History settings
  HISTSIZE=200
  SAVEHIST=400
  HISTFILE=~/.zsh_history
  setopt APPEND_HISTORY
  setopt HIST_IGNORE_DUPS
  bindkey  "^[[H"   beginning-of-line
  bindkey  "^[[F"   end-of-line
  bindkey  "^[[3~"  delete-char
  # Enable user completions (optional: include your custom dir)
  fpath=(~/.zsh/completions $fpath)

  # Load completion system once
  autoload -Uz compinit
  compinit

  alias dotfiles-git-get="git clone git@github.com:JayDeeAU/dotfiles.git $HOME/dotfiles"

  [ -f "$HOME/.aliases" ] && source "$HOME/.aliases"
  [ -f "$HOME/.aliases.local" ] && source "$HOME/.aliases.local"
  [ -f "$HOME/.functions" ] && source "$HOME/.functions"
  [ -f "$HOME/.functions.local" ] && source "$HOME/.functions.local"
  [ -f "$HOME/.exports" ] && source "$HOME/.exports"
  [ -f "$HOME/.exports.local" ] && source "$HOME/.exports.local"
  for f in "$HOME/.functions"/*.sh; do [ -f "$f" ] && source "$f"; done
  for f in "$HOME/.functions.local.d"/*.sh; do [ -f "$f" ] && source "$f"; done
  export PATH="/home/joe/.local/bin:$PATH"
  eval "$(starship init zsh)"
  export PATH="$HOME/.npm-packages/bin:$PATH"
  export PATH="$HOME/.local/bin:$PATH"
  [[ $- == *i* ]] && dotfiles_check_updates
  [ -f "$HOME/.config/zsh/zshrc-shared" ] && source "$HOME/.config/zsh/zshrc-shared"
