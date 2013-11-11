# =============================================================================
# = postgres                                                                  =
# =============================================================================

db_host=''
db_name=''
db_user=''
db_pass=''


# =============================================================================
# = osm                                                                       =
# =============================================================================

# Cache size for osm2pgsql tool, the larger this is, the less time it should
# take. Change it based on the amount of RAM on the target machine.
# See http://www.remote.org/frederik/tmp/ramm-osm2pgsql-sotm-2012.pdf for an
# idea of how long it can take based on cache size and hard drive type.
osm2pgsql_cache_size_mb=800

# URL of OSM data to be imported. See http://download.geofabrik.de/ for daily
# OpenStreetMap extracts.
osm_data_url=''


# =============================================================================
# = citysdk                                                                   =
# =============================================================================

# Admin user password in CitySDK app is bootstrapped with this password.
citysdk_app_admin_password=''

ep_code=''
ep_description=''
ep_api_url=''
ep_cms_url=''
ep_info_url=''
ep_services_url=''
ep_tileserver_url=''
ep_maintainer_email=''
ep_mapxyz=''

