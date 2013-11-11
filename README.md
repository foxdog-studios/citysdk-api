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

Arch Linux developers can run `scripts/setup/arch.sh` to install development
dependencies and set up the repository


Deployment
----------

To deploy CitySDK to a clean installation of Ubuntu 12.04 LTS (64-bit):

1.  Create yourself an administrative account (i.e., the user is a member of
    the `wheel` group) on the target machine.

2.  From your local CitySDK repository, copy the scripts in the
    `scripts/deploy/target` directory to the target machine, e.g.,
    `scp scripts/deploy/target* user@target:`.

3.  On the target machine, run `target-1.sh`. You may be prompted for your
    password by `sudo`.

4.  Note `deploy`'s password print just before the script finishes.

5.  Reboot the target machine to ensure all packages upgrades take effect.

6.  Set up passwordless log in between your local user and the `deploy` user on
    the target machine (e.g., using `ssh-copy-id`).

7.  On the target machine, run `target-2.sh`. You may be prompted for your
    password by `sudo`.

8.  From your local repository, run `scripts/deploy/local.sh`.


### Testing

Deployment can be tested using a VirtualBox. The following functions may be
useful when testing. They should be added to your `.bashrc` on the target
machine.

    function _deploy()
    {
        local num=${1}
        local remote=local_user@path/to/repository
        local src=${remote}/scripts/deploy/target/target-${num}.sh
        local dst=${HOME}/deploy-${num}.sh
        scp "${src}" "${dst}" && "${dst}" "${@:2}"
    }

    function deploy-1()
    {
        _deploy 1 "${@}"
    }

    function deploy-2()
    {
        _deploy 2 "${@}"
    }

