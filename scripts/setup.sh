#!/usr/bin/env bash

set -o errexit
set -o nounset


# ==============================================================================
# = Configuration                                                              =
# ==============================================================================

applications=(
    server
    cms
    rdf
    devsite
)

config_applications=(
    server
    cms
    devsite
)

packages=(
    git
    libyaml
    postgresql-libs
)

repo=$(realpath "$(dirname "$(realpath -- "${BASH_SOURCE[0]}")")/..")

rvm_bin=~/.rvm/bin/rvm
rvm_gemset=citysdk

ruby_version=1.9.3


# ==============================================================================
# = Helpers                                                                    =
# ==============================================================================

function ensure_line()
{
    local line=$1
    local path=$2

    if ! grep --fixed-strings  \
              --line-regexp    \
              --quiet          \
              "--regexp=$line" \
              "$path"; then
        printf '%s\n' "$line" >> "$path"
    fi
}


function rvm()
{
    "$rvm_bin" "$ruby_version@$rvm_gemset" "$@"
}


function rvmdo()
{
    # Leave 'do' quoted. Without, VIM gets confused.
    rvm 'do' "$@"
}


# ==============================================================================
# = Tasks                                                                      =
# ==============================================================================

function packages-install()
{
    sudo pacman --noconfirm --sync --needed --refresh "${packages[@]}"
}


function rvm-install()
{
    # /etc/gemrc is part of Arch Linux's Ruby package
    if [[ -f /etc/gemrc ]]; then
        sudo sed -i '/gem: --user-install/d' /etc/gemrc
    fi

    curl --location https://get.rvm.io | bash -s stable

    local path=~/.bash_profile
    if [[ -f "$path" ]]; then
        ensure_line 'source ~/.profile' "$path"
    fi
}


function rvm-ruby()
{
    rvm install "ruby-$ruby_version"
}


function rvm-gemset()
{
    local app

    rvm gemset create "$rvm_gemset"

    for app in "${applications[@]}"; do
        echo Bundling: $app
        rvmdo bundle install "--gemfile=$repo/$app/Gemfile"
    done
}


function config-init()
{
    local config=$repo/config
    local template=$config/config.template.sh
    local config_local=$config/local

    mkdir --parent "$config_local"

    local development=$config_local/development.sh

    if [[ ! -f "$development" ]]; then
        cp "$template" "$development"
    else
        echo $development already exists, skipping
    fi

    local production=$config_local/production.sh

    if [[ ! -f "$production" ]]; then
        cp "$template" "$production"
    else
        echo $production already exists, skipping
    fi
}


function config-ln()
{
    local app

    for app in "${config_applications[@]}"; do
        echo Soft-linking config for: $app
        ln -f -s ../config/local/development.json "$repo/$app/config.json"
    done
}


function manual()
{
    cat <<-'EOF'
		1) Ensure $HOME/.rvm/bin is on your $PATH
	EOF
}

# ==============================================================================
# = Command line interface                                                     =
# ==============================================================================

all_tasks=(
    packages-install
    rvm-install
    rvm-ruby
    rvm-gemset
    config-init
    config-ln
    manual
)

function usage()
{
    cat <<-'EOF'
		Set up a development environment

		Usage:

		    setup.sh TASK

		Tasks:

		    packages-install
		    rvm-install
		    rvm-ruby
		    rvm-gemset
		    config-init
		    config-ln
		    manual
	EOF
    exit 1
}


for task in "$@"; do
    if [[ "$(type -t "$task" 2> /dev/null)" != function ]]; then
        usage
    fi
done

for task in "${@:-${all_tasks[@]}}"; do
    echo -e "\e[5;32mTask: $task\e[0m"
    "$task"
done

