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

1.  Create a `citysdk` user on the target machine and add the user to the
    `wheel` group.

2.  Copy `scripts/deploy/server.sh` to the target machine as `citysdk`, e.g.,
    `scp scripts/deplpoy/server.sh citysdk@target:`.

3.  Run `server.sh` on the target machine as the `citypsdk` user.

4.  Delete the `server.sh` script from the target machine.

5.  Remove the `citysdk` user from the `wheel` group.

6.  Reboot the system to allow all upgrades to take effect.

