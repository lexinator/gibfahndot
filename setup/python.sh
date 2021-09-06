#!/usr/bin/env zsh

set -eux

pip3_modules=(
  neovim-remote                 # Connect to existing nvim sessions (try `g cm` in a nvim terminal).
  pynvim                        # Python plugin framework for neovim.
  'python-language-server[all]' # Python language server (I use it in neovim).
  vim-vint                      # Vim linter.
)

# Install or update pip modules.
pip=(python3 -m pip)
pip_installed="$(${pip[@]} list | awk '{print $1}')"
pip_outdated="$(${pip[@]} list --outdated | awk '{print $1}')"

# Update pip itself.
${pip[@]} install --upgrade pip

for module in "${pip3_modules[@]}"; do
  if ! echo $pip_installed | grep -qx "${module%\[*}" \
    || echo $pip_outdated | grep -qx "${module%\[*}"; then
    ${pip[@]} install --user --upgrade "$module"
  else
    # TODO(gib): add skipping in the check command.
    :
  fi
done
