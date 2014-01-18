#!/usr/bin/env zsh

setopt err_exit
source ${0:h}/library.zsh


# ==============================================================================
# = Configuration                                                              =
# ==============================================================================

applications=(
    server
    cms
    rdf
    devsite
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
    underscore-cli
)

pacman_packages=(
    expect
    git
    libyaml
    memcached
    nodejs
    python2-virtualenv
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
        sudo sed -i '/gem: --user-install/d' /etc/gemrc
    fi

    curl --location https://get.rvm.io | bash -s stable
}

function install_ruby()
{
    rvm install ruby-$ruby_version
}

function install_gemset()
{
    rvm gemset create $ruby_gemset

    local app
    for app in $applications; do
        bundle install --gemfile=$repo/$app/Gemfile
    done
}

function create_ve()
{
    virtualenv-2.7 $env
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

    local data=/var/lib/postgres/data
    if [[ "$(pdo ls -1 $data | wc -l)" -eq 0 ]]; then
        pdo initdb --locale en_GB.UTF-8 -D $data
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
    setopt LOCAL_OPTIONS
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

		    setup [TASK...]

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

