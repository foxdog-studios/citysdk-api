CitySDK
=======

.comThe CitySDK Mobility API, developed by [Waag Society](http://waag.org/) is a
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

Requirements
------------

Supported development environments:

    * Arch Linux (64-bit)

Supported production environments:

    * Ubuntu 12.04 LTS Server (64-bit)


Set up development environment
------------------------------

To set up a development environment, Arch Linux users should run;

    [local]$ ./scripts/setup.sh


Resetting the development database
----------------------------------

You can reset the local postgresql database in your development environment (the
one created by `./scripts/setup.sh`)

    [local]$ ./scripts/reset-db.sh


Configuration
-------------

1.  Complete the `development.sh` and `production.sh` configurations in the
    `config/local` directory. See the comments in these configuration files for
    descriptions of what each field represents.

2.  To generate JSON versions of the development and production configurations
    (which are used by the apps) run

        [local]$ ./scripts/create_config.sh


Deployment
----------

These deployment instructions describe how to deploy CitySDK to a clean
installation of Ubuntu 12.04 LTS (64-bit) and will install

- the API server,
- the developer site server,
- the RDF server,
- the CMS server.

These instructions do _not_ set up any importers or tile servers.

Before deploying, ensure you've set up your development environment.

1.  Create yourself an administrative account (i.e., the user is a member of
    the `sudo` group) on the target machine.

2.  From your local repository, copy the `scripts/setup-production` directory
    and the production configuration to the target machine, e.g.;

        [local]$ scp -r scripts/setup-production user@target:setup
        [local]$ scp config/local/production.sh setup/config.sh

    Note: Make sure you name the files like the example above.

3.  On the target machine, run;

        [target]$ ./setup/setup-1.sh

    Note: You may be prompted for your password by `sudo`.

4.  Reboot the target machine to ensure all package upgrades take effect.

5.  Set up passwordless log in between your local user and the `deploy` user on
    the target machine, e.g.;

        [local]$ ssh-copy-id deploy@target_host

    Note: Check `config/local/production.sh` for deploy's password.

6.  From your local repository, run;

        [local]$ ./scripts/deploy.sh

7.  On the target machine, run;

        [target]$ ./setup/setup-2.sh

    Note: You may be prompted for your password by `sudo`.


### Testing a deployment on a staging server

Deployment can be tested using a VirtualBox as a staging server.

The following functions may be useful when testing. They should be added to
your `.bashrc` on the target machine.

    function _setup()
    {
        local num=${1}
        local repo=local_user@host_name:path/to/repository
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

Then call

    [target]$ setup-1

or

    [target]$ setup-2

Which will pull over any changes you have made on your local develpoment
machine and run the setup script.

