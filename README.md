CitySDK
=======

The CitySDK Mobility API, developed by [Waag Society](http://waag.org/) is a
layer-based data distribution and service kit. Part of
[CitySDK](http://citysdk.eu), a European project in which eight cities
(Manchester, Rome, Lamia, Amsterdam, Helsinki, Barcelona, Lisbon and Istanbul)
and more than 20 organisations collaborate, the CitySDK Mobility API enables
easy development and distribution of digital services across different cities.

Although the initial focus in developing this part of the API was on mobility,
the approach chosen allows any (open) data to be made available in a uniform
and flexible manner.

A running implementation of the api can be found at
[http://dev.citysdk.waag.org](http://dev.citysdk.waag.org); this is also where
you'll find additional documentation.


Set up
------

To set up a development environment, Arch Linux users should run;

    [local]$ ./scripts/setup/arch.sh


Configuration
-------------

1. Complete the `development.sh` and `production.sh` configurations in the
   `config/local` directory.

2. To generate JSON versions of the development and production configurations
   run

    [local]$ ./scripts/create_config.sh

3. Enter the host name of the production machine into
   `config/local/production_hostname.txt`.


Deployment
----------

Before deploying, ensure you've set up your development environment. To deploy
CitySDK to a clean installation of Ubuntu 12.04 LTS (64-bit):

1.  Create yourself an administrative account (i.e., the user is a member of
    the `wheel` group) on the target machine.

2.  From your local repository, copy the `scripts/setup-production` directory
    and the production configuration to the target machine, e.g.;

        [local]$ scp -r scripts/setup-production user@target:setup
        [local]$ scp config/local/production.sh setup/config.sh

    Note: Make sure you name the files like the example above.

3.  On the target machine, run;

        [target]$ ./setup/setup-1.sh

    Note: You may be prompted for your password by `sudo`.

4.  Record `deploy`'s password printed just before the script finishes.

5.  Reboot the target machine to ensure all package upgrades take effect.

6.  Set up passwordless log in between your local user and the `deploy` user on
    the target machine, e.g.;

        [local]$ ssh-copy-id deploy@target_host

    You'll be prompted from password printed by `setup-1.sh`

8.  From your local repository, run;

        [local]$ ./scripts/deploy.sh

7.  On the target machine, run;

        [target]$ ./setup/setup-2.sh

    Note: You may be prompted for your password by `sudo`.


### Testing

Deployment can be tested using a VirtualBox. The following functions may be
useful when testing. They should be added to your `.bashrc` on the target
machine.

    function _setup()
    {
        local num=${1}
        local repo=local_user@path/to/repository
        local setup=${HOME}/setup

        mkdir --parent "${setup}"

        local src=${repo}/scripts/setup-production/*.sh
        scp -r "${src}" "${setup}"

        local src="${repo}/config/local/production.sh"
        dst=${setup}/config.sh
        scp "${src}" "${dst}"

        "${setup}/setup-${num}.sh" "${@:2}"
    }

    function setup-1()
    {
        _setup 1 "${@}"
    }

    function setup-2()
    {
        _setup 2 "${@}"
    }

