#!/usr/bin/env zsh

setopt ERR_EXIT
setopt NO_UNSET

source -- ${0:h}/library.zsh

# ==============================================================================
# = Configuration                                                              =
# ==============================================================================

require_bundler=(
    cms
    devsite
    rdf
    server
)

aur_packages=(
    osm2pgsql-git
)

config_applications=(
    server
    cms
    devsite
)

global_node_packages=(
    bower
    underscore-cli
)

pacman_packages=(
    expect
    git
    libyaml
    memcached
    nodejs
    postgresql
    postgis
    python2-virtualenv
    wget
    yaourt
    zsh
)


# ==============================================================================
# = Tasks                                                                      =
# ==============================================================================

function add_archlinuxfr_repo()
{
    if grep --quiet '\[archlinuxfr\]' /etc/pacman.conf; then
        return
    fi

    sudo tee --append /etc/pacman.conf <<-'EOF'
		[archlinuxfr]
		Server = http://repo.archlinux.fr/$arch
		SigLevel = Never
	EOF
}

function install_pacman_packages()
{
    sudo pacman --noconfirm --sync --needed --refresh $pacman_packages
}

function install_aur_packages()
{
    local package

    for package in $aur_packages; do
        if ! pacman -Q $package &> /dev/null; then
            yaourt --noconfirm --sync $package
        fi
    done
}

function install_rvm()
{
    # /etc/gemrc is part of Arch Linux's Ruby package
    if [[ -f /etc/gemrc ]]; then
        sudo sed --in-place '/gem: --user-install/d' /etc/gemrc
    fi

    curl --location https://get.rvm.io | bash -s stable
}

function install_ruby()
{
    unsetopt NO_UNSET
    rvm install ruby-$ruby_version
    rvm use $ruby_version@$ruby_gemset
    setopt NO_UNSET
}

function install_gemset()
{
    unsetopt NO_UNSET
    rvm gemset create $ruby_gemset
    setopt NO_UNSET

    local dirname
    for dirname in $require_bundler; do
        bundle install --gemfile=$repo/$dirname/Gemfile
    done
}

function create_ve()
{
    if [[ ! -d $env ]]; then
        virtualenv --python=python2.7 $env
    fi
}

function install_python_packages()
{
    ve pip install --requirement $repo/requirement.txt
}

function install_global_node_packages()
{
    sudo --set-home npm install --global $global_node_packages
}

function configure_memcached()
{
    sudo systemctl enable memcached.service
    sudo systemctl start memcached.service
}

function configure_postgresql()
{
    sudo systemd-tmpfiles --create postgresql.conf

    local root=/var/lib/postgres
    sudo chown -R postgres:postgres $root

    local data=$root/data
    if [[ "$(sudo --user=postgres ls -1 $data | wc -l)" -eq 0 ]]; then
        sudo --login --user=postgres initdb --locale en_GB.UTF-8 -D $data
    fi

    sudo systemctl enable postgresql.service
    sudo systemctl start postgresql.service
}

function init_config()
{
    local src=$repo/templates/config
    local cfg=$repo/local/config
    local dst=$cfg/development
    local lnk=$cfg/default

    if [[ ! -d $dst ]]; then
        mkdir --parents $dst:h
        cp --recursive $src $dst
    fi

    if [[ ! -e $lnk ]]; then
        ln --symbolic $dst:t $lnk
    fi
}

function link_config()
{
    local app

    for app in $config_applications; do
        ln --force                             \
           --symbolic                          \
           --verbose                           \
           ../local/config/default/server.json \
           $repo/$app/config.json
    done
}

function manual()
{
    cat <<-'EOF'
		1) Ensure $HOME/.rvm/bin is on your $PATH
	EOF
}


# ==============================================================================
# = Helpers                                                                    =
# ==============================================================================

function ve()
{
    setopt local_options
    unsetopt NO_UNSET

    source $env/bin/activate
    $@
    deactivate
}


# ==============================================================================
# = Command line interface                                                     =
# ==============================================================================

tasks=(
    add_archlinuxfr_repo
    install_pacman_packages
    install_aur_packages
    install_rvm
    install_ruby
    install_gemset
    create_ve
    install_python_packages
    install_global_node_packages
    configure_memcached
    configure_postgresql
    init_config
    link_config
)

function usage()
{
    cat <<-'EOF'
		Set up a development environment

		Usage:

		    setup.zsh [TASK...]

		Tasks:

		    add_archlinuxfr_repo
		    install_pacman_packages
		    install_aur_packages
		    install_rvm
		    install_ruby
		    install_gemset
		    create_ve
		    install_python_packages
		    install_global_node_packages
		    configure_memcached
		    configure_postgresql
		    init_config
		    link_config
	EOF
    exit 1
}

for task in $@; do
    if [[ ${tasks[(i)$task]} -gt ${#tasks} ]]; then
        usage
    fi
done

for task in ${@:-${tasks[@]}}; do
    print -P -- "%F{green}Task: $task%f"
    $task
done

