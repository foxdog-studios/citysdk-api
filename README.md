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

2.  From your local CitySDK repository, copy the `scripts/deploy/server.sh`
    script to the target machine, e.g.,
    `scp scripts/deplpoy/server.sh user@target:`.

3.  Run `server.sh` on the target machine. You may be prompted for your
    password by `sudo`.

5.  Note `deploy`'s password print just before the script completes.

4.  Delete the `server.sh` script from the target machine.

6.  Reboot the system to allow all upgrades to take effect.

7.  Set up passwordless log in between your local user and the `deploy` user on
    the target machine (e.g., using `ssh-copy-id`).

8.  Using your account on the target machine, delete `deploy`'s password, e.g.,
    `sudo passwd --delete deploy`.

9.  From your local repository, run `scripts/deploy/local.sh`.

