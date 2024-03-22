#!/bin/bash
set -euo pipefail
IFS=$'\n\t'
# why and how to use it: http://redsymbol.net/articles/unofficial-bash-strict-mode/

# arg handling https://www.baeldung.com/linux/use-command-line-arguments-in-bash-script

set +u
while getopts 'b:' flag
do
    case "${flag}" in
        b) feature_branch=${OPTARG};;
        [?])	echo >&2 "Syntax: $0 -b <feature_branch_name>"
              exit 1;;
    esac
done
set -u

curr_branch=$(git branch --show-current)
if [ "$curr_branch" != "main" ]
then
      echo "You must be on main branch to create a feature branch"
      exit 1
fi

anyuntracked() {
    return `git ls-files -o --directory --exclude-standard | wc -l`
}

exit_code=0

# look for untracked files
anyuntracked || exit_code=$?
if [[ ${exit_code} -ne 0 ]]
then
  echo "You have untracked files, please  add & commit or stash them:"
  git ls-files -o --directory --exclude-standard
  exit 1
fi

# look for unstaged changes
anynotstaged=$(git --no-pager diff --stat | wc -l)
if [[ anynotstaged -ne 0 ]]; then
  echo 'There are unstaged changes, please add & commit or stash them:'
  git --no-pager diff --stat
  exit 1
fi

# look for uncommited changes
anyuncommited=$(git --no-pager diff --cached --stat | wc -l)
if [[ anyuncommited -ne 0 ]]; then
  echo 'There are uncommited changes, please add & commit or stash them:'
  git --no-pager diff --cached --stat
  exit 1

fi

# create the feature branch
git checkout -b ${feature_branch}

# get config count
config_count=$(cat shopify.theme.toml | grep 'port = 929' | wc -l)
if [[ ${config_count} -gt 9 ]]; then
  echo "Too many configs in shopify.theme.toml. There are no port numbers left between 9290 and 9299."
  exit 1
fi

# get store from first config
store=$(cat shopify.theme.toml | grep 'store' | head -1 | cut -d'"' -f2)

# get password from first config
password=$(cat shopify.theme.toml | grep 'password' | head -1 | cut -d'"' -f2)

# get next port number
highest_port=$(cat shopify.theme.toml | grep 'port = 929' | tail -1 | cut -d' ' -f3)
next_port=$((highest_port + 1))

# add dev theme config to shopify.theme.toml file
cat <<EOT >> shopify.theme.toml

[environments.${feature_branch}]
theme = "${feature_branch}"
store = "${store}"
password = "${password}"
port = ${next_port}
# shopify theme dev --theme-editor-sync -e ${feature_branch}
EOT

# push as new theme to shopify
shopify theme push -u -t ${feature_branch}

echo "Feature branch ${feature_branch} created and pushed to shopify."
echo 
echo "Now you can start local dev with:"
echo shopify theme dev --theme-editor-sync -e ${feature_branch}