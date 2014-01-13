# = PostgreSQL ================================================================

db_host=''
db_name=''
db_user=''
db_pass=''


# = OSM =======================================================================

# Cache size for osm2pgsql tool, the larger this is, the less time it should
# take. Change it based on the amount of RAM on the target machine.
# See http://www.remote.org/frederik/tmp/ramm-osm2pgsql-sotm-2012.pdf for an
# idea of how long it can take based on cache size and hard drive type.
osm2pgsql_cache_size_mb=800

# URL of OSM data to be imported. See http://download.geofabrik.de/ for daily
# OpenStreetMap extracts.
osm_data_url=''


# = CitySDK ===================================================================

# Admin user password in CitySDK app is bootstrapped information
citysdk_app_admin_password=''
citysdk_app_admin_name=''
citysdk_app_admin_email=''
citysdk_app_admin_organization=''
citysdk_app_admin_domains=''

# EP is end point, each instance of citysdk is an end point
ep_code=''
ep_description=''
# Api URL e.g. api.citysdk.example.com
ep_api_url=''
# CMS URL e.g. cms.citysdk.example.com
ep_cms_url=''
ep_info_url=''
ep_services_url=''
ep_tileserver_url=''
ep_maintainer_email=''
ep_mapxyz=''

# Path to where import logs from the cms will be written to.
cms_import_log_path=''
# Path to the directory where the cms will write the uploaded data to before
# it is inserted into the database, e.g., processed uploaded CSV files
cms_tmp_file_dir=''


# = Server ====================================================================

# The host name of the machine to deploy to.
host_name=''

# The domain name used to access this machine. For example, if the API
# should be at http://citysdk.com/, then server_name should be citysdk.
server_name=''

# A temporary password to give assign to the deploy use before
# password-less authentication is set up.
server_deploy_password=''

