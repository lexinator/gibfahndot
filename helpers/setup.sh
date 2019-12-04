# shellcheck shell=bash disable=SC1090

# Helper functions and vars for use in the other setup scripts. Most of these are from
# my gibrc, but that's not necessarily installed yet.

# Include (source) with this line (assuming you're in dot):
# . $(dirname $0)/helpers/setup.sh # Load helper script from dot/helpers.

# No POSIX way to get dir of sourced script.
[ "$BASH_VERSION" ] && thisDir="$(dirname "${BASH_SOURCE[0]}")"
[ "$ZSH_VERSION" ] && thisDir="$(dirname "$0")"
[ -z "$thisDir" ] && thisDir="./helpers"

# Get colour aliases.
. "$thisDir"/colours.sh

export XDG_CONFIG_HOME=${XDG_CONFIG_HOME:-"$HOME/.config"} # Config stuff should go here.
export XDG_CACHE_HOME=${XDG_CACHE_HOME:-"$HOME/.cache"} # Cache stuff should go here.
export XDG_DATA_HOME=${XDG_DATA_HOME:-"$HOME/.local/share"} # Data should go here.

: "${BUILD_DIR:="$HOME/code/build"}" # Directory to clone/build things in.
mkdir -p "$BUILD_DIR"
: "${BIN_DIR:="$HOME/bin"}" # Directory to copy binaries to.
mkdir -p "$BIN_DIR"

mkdir -p "$HOME/tmp"
[[ ! -e "$HOME"/tmp/dot.log ]] || mv "$HOME"/tmp/dot.log{,.old}

exists() { type "$1" >/dev/null 2>&1; } # Check if command exists (is in path).

### Logging functions

# Used when you're starting a new section.
log_section() {
  printf "❯❯❯ Installing: %s\n" "$@"
}

# Used when you're going to install something.
log_get() {
  printf "${CYAN}❯❯❯ Installing:${NC} %s\n" "$@"
}

# Used when you're going to install something.
log_update() {
  printf "${CYAN}❯❯❯   Updating:${NC} %s\n" "$1"
}

# Used when you're not going to install something.
log_skip() {
  printf "${YELLOW}❯❯❯   Skipping:${NC} %s\n" "$@"
}

log_debug() {
    printf "$1\n" >> "$HOME"/tmp/dot.log
}

# `if no foo` then foo isn't in $XDG_DATA_HOME and we should install it.
no() { # Do we need to install $1?
  if [ ! -e "$XDG_DATA_HOME/$1" ]; then
    log_get "$1"
    return 0 # Directory is missing.
  else
    log_skip "$1 (already exists)."
    return 1 # Directory not missing.
  fi
}

# `if not foo` then foo isn't in path and we should install it.
not() { # Do we need to install $1?
  if ! exists "$1"; then
    log_get "$@"
    return 0 # Binary not in path.
  else
    log_skip "$@"
    return 1 # Binary in path.
  fi
}

# Some machines can't understand GitHub's https certs for some reason.
gitClone() {
  log_get "$@"
  REPO=$1; shift # First arg is repo, rest are passed on to git clone.
  git clone "git@github.com:$REPO.git" "$@" ||
    git clone "https://github.com/$REPO.git" "$@"
}

# TODO(gib): Should this update from the up remote?
# TODO(gib): Return error code if rebase had conflicts (and print next steps).
# TODO(gib): Maybe create a backup branch.
gitUpdate() {
  DIR="$1" # First arg is directory.

  local skip exit_code uncommitted_changes upstream_commits upstream_submodule_updates
  pushd "$DIR" >/dev/null || return 1

  git fetch --all >/dev/null || return 1

  skip=true   # Whether we did anything or just skipped this update.
  exit_code=200 # What the function should return (default 200 == no changes so skipped).
  uncommitted_changes="$(git status --porcelain)" # Is there anything in the working tree.
  upstream_commits="$(git rev-list -1 @{u} --not HEAD)" # Does upstream have something we don't.
  upstream_submodule_updates="$(git submodule status --recursive 2>/dev/null | grep -q '^+')"

  if [[ -n "$upstream_commits" || -n "$upstream_submodule_updates" ]]; then
    unset skip # We need to do some work.
    exit_code=0 # Means we did work and didn't fail.

    # If you have uncommitted changes, commit them.
    if [[ -n "$uncommitted_changes" ]]; then
      git add -A
      # Amend the previous commit if it's an autogenerated one.
      local flags=""
      { [[ "$(g show -s --pretty=%s)" = "My changes as of "* ]] && flags=--amend; } || true
      git commit -m "My changes as of $(date)" $flags
    fi

    # If upstream is a different commit as HEAD, rebase:
    if [[ -n "$upstream_commits" ]]; then
      git rebase

      if [ -d "$(git rev-parse --git-path rebase-merge &>/dev/null)" ] ||
         [ -d "$(git rev-parse --git-path rebase-apply &>/dev/null)" ]; then
        addError "Git rebase failed for $1"
        exit_code=1
        git rebase --abort
      fi
    fi

    # If upstream submodule is a different sha from head, update it:
    if [ "$upstream_submodule_updates" ]; then
      git submodule update --rebase --recursive
    fi
  fi

  { [[ -n "$skip" ]] && log_skip "$@"; } || log_update  "$@"
  popd >/dev/null || return 1
  return "$exit_code"
}

# If the repo isn't there, clone it, if it is, update it.
# $1: repo to clone (org/repo).
# $2: dir to clone into.
gitCloneOrUpdate() {
  local DIR="$2" # Directory to clone into.
  if [ ! -d "$DIR" ]; then
    gitClone "$@"
  else
    gitUpdate "$2"
  fi
}

# `hasSudo || exit` in individual install scripts to check for sudo.
# Sets the $sudo variable to be blank (if running as root) or sudo if not.
hasSudo() {
  if [ "$(id -u)" = 0 ]; then
    sudo=
    return 0
  fi
  if [ "$NO_SUDO" ] || ! sudo -v; then
    log_skip "Packages (user doesn't have sudo)."
    return 1
  else
    log_get "Packages."
    sudo=sudo
    return 0
  fi
}

# Summary of what has run, pass fail status plus optional error message. $1 is
# what it's the status of (should be all-caps).
finalOutput() {
  local status="$?"
  printf "${BCYAN}❯❯❯ %s STATUS:${NC} %s\n" "$1" "$status"
  [ "$FINAL_OUTPUT" ] && printf "${BGBRED}❯❯❯ FINAL OUTPUT:${NC} %s\n" "$FINAL_OUTPUT"
  exit "$status"
}

# Summary of what has run, pass fail status plus optional error message. $1 is
# what it's the status of (should be all-caps).
addError() {
  FINAL_OUTPUT="$FINAL_OUTPUT\n${RED}ERR:${NC} $*"
}

# For usage see updateMacOSKeyboardShortcut
updateMacOSDefaultDict() {
  local domain subdomain key val val2 currentVal;
  domain="$1"; shift
  subdomain="$1"; shift
  key="$1"; shift
  val="$1"; shift
  [[ "$#" != 0 ]] && printf "Wrong number of args" && return 1
  val2="$(sed 's/\\/\\\\/g' <<<"$val")"  # `defaults` doubles the \ for no reason sometimes.

  # If the dict hasn't been initialised yet, create it.
  if ! defaults read "$domain" "$subdomain" >/dev/null; then
    defaults write "$domain" "$subdomain" -dict
  fi

  # Get the current value of the dict[key] (empty if unset).
  currentVal="$(defaults read "$domain" "$subdomain"                 \
                | grep -F "$key"                                     \
                | sed -E "s/ *\"?$key\"? *= *\"?([^\"]*)\"?;/\1/" \
              )"

  if [[ "$currentVal" == "$val" || "$currentVal" == "$val2" ]]; then
    log_skip "macOS default shortcut $domain $key is already set to '$currentVal'"
    return 0
  fi

  if [[ -n "$currentVal" ]]; then
    log_update  "macOS default shortcut $domain $key is currently set to '$currentVal', changing to '$val'"
  else
    log_update  "macOS default shortcut $domain $key is unset, setting it to '$val'"
  fi

  defaults write "$domain" "$subdomain" -dict-add "$key" "$val"
}

# Run:
#   defaults find NSUserKeyEquivalents
# Example output:
#   Found 1 keys in domain 'com.foo.bar': {
#       NSUserKeyEquivalents =     {
#           baz = bat;
#       };
#   }
# Call to use:
#   updateKeyboardShortcuts "com.foo.bar" "baz" "bat"
# Set sudo=sudo for commands that need root access.
updateMacOSKeyboardShortcut() {
  updateMacOSDefaultDict "$1" NSUserKeyEquivalents "$2" "$3"
  if ! defaults read com.apple.universalaccess com.apple.custommenu.apps | grep -qF "$1"; then
    log_update  "macOS default shortcut $1 is not in com.apple.universalaccess com.apple.custommenu.apps, adding it."
    defaults write com.apple.universalaccess com.apple.custommenu.apps -array-add "$1" \
      || echo "Add the current Terminal app to System Preferences -> Privacy -> Full Disk Access."
  fi
}

# If you get:
#   defaults read foo bar -> 1
#   defaults read-type foo bar -> Type is integer
# Then you should set with:
#   updateMacOSDefault foo bar -int 1
updateMacOSDefault() {
  local domain key val_type val currentVal;
  domain="$1"; shift
  key="$1"; shift
  val_type="$1"; shift
  val="$1"; shift
  [[ "$#" != 0 ]] && printf "Wrong number of args" && return 1
  currentVal="$(defaults read "$domain" "$key")"

  if [[ "$currentVal" == "$val" ]]; then
    log_skip "macOS default $domain $key is already set to $val"
    return 0
  fi

  if [[ -n "$currentVal" ]]; then
    log_update  "macOS default $domain $key is currently set to $currentVal, changing to $val"
  else
    log_update  "macOS default $domain $key is unset, setting it to $val"
  fi

  defaults write "$domain" "$key" "$val_type" "$val"
}
