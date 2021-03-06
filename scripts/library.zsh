# ==============================================================================
# = Paths                                                                      =
# ==============================================================================

repo=${$(realpath $0):h:h}

config=$repo/local/config
config_default=$config/default
env=$repo/env


# ==============================================================================
# = Local configuration                                                        =
# ==============================================================================

if (( ! $+CITYSDK_CONFIG_DIR )); then
    export CITYSDK_CONFIG_DIR=$config_default
fi

if [[ ! -d $CITYSDK_CONFIG_DIR ]]; then
    print -P -- '%F{red}No configuration!%f'
    unset CITYSDK_CONFIG_DIR
else
    CITYSDK_CONFIG_DIR=$(realpath -- $CITYSDK_CONFIG_DIR)
fi

function config()
{
    local filename=$1
    local key=$2

    underscore --in $CITYSDK_CONFIG_DIR/${filename}.json \
               --outfmt text                             \
               extract $key
}

function config-dev()
{
    config dev $@
}

function config-server()
{
    config server $@
}

function config-setup()
{
    config setup $@
}


# ==============================================================================
# = Rackup                                                                     =
# ==============================================================================

function serve()
{
    local dirname=$1
    local app=${2:-$dirname}

    unsetopt ERR_EXIT NO_UNSET
    cd $repo/$dirname
    setopt ERR_EXIT NO_UNSET
    bundle exec rerun "rackup --port $(config-dev $app.port) --server thin"
}


# ==============================================================================
# = Ruby                                                                       =
# ==============================================================================

if [[ -r ~/.rvm/scripts/rvm ]]; then
    unsetopt NO_UNSET
    source ~/.rvm/scripts/rvm
    setopt NO_UNSET
fi

ruby_version=2.1.2
ruby_gemset=citysdk

if (( $+commands[rvm] )); then
    unsetopt NO_UNSET
    rvm use $ruby_version@$ruby_gemset
    setopt NO_UNSET
fi


# ==============================================================================
# = Virtual environment                                                        =
# ==============================================================================

if [[ -d $env ]]; then
    function active_virtual_env()
    {
        setopt local_options
        unsetopt no_unset

        source $env/bin/activate
    }

    active_virtual_env
    unfunction active_virtual_env
fi

