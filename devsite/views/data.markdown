## Data available via CitySDK

The following data is currently available via CitySDK. You can use the <a class="ep_cms_url">CMS</a> if you want more detailed information, or if you want to add or update data.

<ul id="layers"></ul>
<script src="http://d3js.org/d3.v3.min.js"></script>
<script>

  var rows = {
    "description": "Description",
    "category": "Category",
    "organization": "Organization",
    "data_sources": "Data sources",
  };
  var keys = [];
  for(var k in rows) keys.push(k);


  d3.json(epApiUrl + "/layers?per_page=999", function(data) {
    if (data.results.length) {
      var ul = d3.select("#layers").selectAll("li")
          .data(data.results)
        .enter().append("li")
          .sort(function(a, b) { return a.name > b.name; });

      ul.append("h3")
        .html(function(d) { return d.name ;})

      var table = ul.append("table");

      keys.forEach(function(k) {
        var tr = table.append("tr")

        tr.append("td")
            .html(rows[k] + ":");

        tr.append("td")
            .html(function(d) { return d[k]; });


      });




        // "name": "pc.nlp6",
        // "category": "administrative.postcodes",
        // "organization": "Waag Society",
        // "owner": "citysdk@waag.org",
        // "description": "Postcodes NL",
        // "data_sources": [
        //     "BAG, Kadaster",
        //     "http://nlextract.nl"
        // ]

    }
  });
</script>
