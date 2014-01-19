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

Requirements
------------

Supported development environments:

    * Arch Linux (64-bit)

Supported production environments:

    * Ubuntu 12.04 LTS Server (64-bit)


# WARNING THESE DEVELOPMENT AND DEPLOYMENT INSTRUCTIONS NEED UPDATED

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


CMS
---

The content management system (CMS) is located in `$repo/cms/`.

The CMS allows users to

- Create new layers
- Add data to layers by uploading files in csv, json and zipped shape formats.

## File uploading through the CMS

Uploading data to the CitySDK through the CMS involves

1.  An initial uploading of the file, where the headers will be extracted from
    the file.

2.  Manual labelling of special semantics of headers in the CMS

3.  Importing of the data using the labels. It uses the headers that were
    manually set by the user to call `$repo/utils/import_file.rb` and import
    the data.

You can check the output of the importer in the import log file set in the
config by `cms_import_log_path`.

### Uploading a CSV

To upload a CSV through the CMS

1.  Check the CSV headers, special column names are matched by the regular
    expressions that can be found in `$repo/gem/lib/citysdk/file_reader.rb`. You
    may need to rename your headers if the data in the column does not represent
    what the file expects.

2.  On the data screen of a layer, select the `csv` file to upload.

3.  After uploading you can set what columns have specific semantic meaning.

4.  Click `add data` and the importer will try and import the data.


### Uploading a zipped shape file

Very much the same as uploading a CSV. An example that works is the
[Manchester Bus Routes data](http://www.infotrafford.org.uk/custom/resources/BusRoutes_SHP-format.zip).


