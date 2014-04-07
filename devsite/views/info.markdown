## Links

 - [CitySDK project site](http://www.citysdk.eu/)
 - [CitySDK Linked Open Data Distribution API endpoint](http://api.citysdk.waag.org/)
 - [Visualization of CitySDK Mobility data](http://dev.citysdk.waag.org/visualisation/)
 - [Map with building and address data](http://dev.citysdk.waag.org/buildings/)
 - [Additional APIs in the CitySDK toolkit](http://www.citysdk.eu/developers/) 

Most important data sources currently available:

- Public transport, schedules and real-time &ndash; GTFS, [openOV](http://www.openov.nl/)
- Amsterdam infrastructure and transportation data &ndash; [DIVV](http://www.amsterdamopendata.nl/data?searchvalue=IVV)
- Dutch addresses and buildings &ndash; [BAG](http://www.kadaster.nl/BAG/)
- [OpenStreetMap](http://www.openstreetmap.org/) data.
- More information about available data sets on the [data page](/data), via the [`/layers` API](http://api.citysdk.waag.org/layers) or in the [CMS](https://cms.citysdk.waag.org/).

## API examples

- [Statistical data of all neighbourhoods in Zwolle](http://api.citysdk.waag.org/admr.nl.zwolle/regions?admr::admn_level=4&layer=cbs&per_page=50)
- [Rain forecast per neighbourhood in Groningen](http://api.citysdk.waag.org/admr.nl.groningen/regions?admr::admn_level=4&layer=rain)
- [All municipalities in the Netherlands](http://api.citysdk.waag.org/admr.nl.nederland/nodes?admr::admn_level=3&per_page=500)
- [Museums in Utrecht](http://api.citysdk.waag.org/admr.nl.utrecht/nodes?osm::tourism=museum&per_page=50)
- [Number of inhabitants of Utrecht](http://api.citysdk.waag.org/admr.nl.utrecht/cbs/aant_inw)
- [Public transport stops in Amsterdam named Leidseplein](http://api.citysdk.waag.org/admr.nl.amsterdam/ptstops?name=Leidseplein)
- [Tram lines that call at a specific stop](http://api.citysdk.waag.org/gtfs.stop.060671/select/ptlines)
- [Next hour's schedule for this stop](http://api.citysdk.waag.org/gtfs.stop.060671/select/now)
- [Adminstrative regions which contain the Olympic Stadium in Amsterdam](http://api.citysdk.waag.org/n798432345/select/regions)
- [Real-time traffic flow on main roads in Amsterdam](http://api.citysdk.waag.org/nodes?layer=divv.traffic)
- [Dutch LF2 bicycle route](http://api.citysdk.waag.org/r2816)
- [Religion in Rome](http://api.citysdk.waag.org/admr.it.roma/nodes?osm::religion)
- [Routes containing specific set of nodes](http://api.citysdk.waag.org/routes?contains=n726817991,n726817955,n726816865)
- [Tram stops on Utrecht-IJsselstein tram route](http://api.citysdk.waag.org/r326516/select/nodes?osm::railway=tram_stop|halt&data_op=or)
