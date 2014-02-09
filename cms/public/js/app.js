var propertyTypes = {
  "anyURI":       "xsd:anyURI",
  "base64Binary": "xsd:base64Binary",
  "boolean":      "xsd:boolean",
  "date":         "xsd:date",
  "dateTime":     "xsd:dateTime",
  "float":        "xsd:float",
  "integer":      "xsd:integer",
  "string":       "xsd:string",
  "time":         "xsd:time"
};

var optionsForSelect = function(a, addSel) {
  var s = '';
  if (addSel == true) {
    s = '<option>select..</option>';
  }
  a.forEach(function(item) {
    s = s + "<option>" + item + '</option>'
  });
  return s;
}

var addHtml = function(a, ts, i) {
  if (a.length < 25) {
    $('#' + ts).parent().html(
      $('<select id="' + ts + '" name="tag_select[' + i + ']"></select>')
        .append(optionsForSelect(a))
    );
  } else {
    $('#' + ts).parent().html(
      $('<input></input>')
        .attr({
          type: 'text',
          size: '14',
          id: ts,
          name: 'tag_select[' + i + ']',
          placeholder: 'layertag'
        })
        .autocomplete({ source: a })
    );
  }
};

var tagsForLayer = function (name, ts, i) {
  if (availableTags[name] != null ) {
    addHtml(availableTags[name], ts, i)
    return;
  }

  $.ajax({
    url: '/layers/' + name + '/keys',
    type: 'get',
    success: function(data) {
      obj = $.parseJSON(data)
      availableTags[l] = obj[0]['keys_for_layer']
      addHtml(availableTags[l], ts, i)
    }
  });
};

var newTagSelect = function (layers) {
  var index = '' + $("#tagselectlist").children().length

  var ls = $(layers)
    .attr('name', 'layer_select[' + index + ']')
    .change(function() {
      tagsForLayer(
        $(this).val(),
        'tag_sel_' + index,
        index
      )
    });

  var ts = $('<input></input>')
    .attr({
      type : 'text',
      size: '14',
      id: 'tag_sel_' + index,
      name: 'tag_select[' + index + ']',
      placeholder: 'layertag'
    })
    .autocomplete({
      source: availableTags['osm']
    });

  ts = $('<span></span>').append(ts);

  var vs = $('<input></input>')
    .attr({
      type: 'text',
      size: '14',
      name: 'tag_value[' + index + ']',
      placeholder: 'anything'
    });

  var li = $('<li></li>').append(ls)
  li.append('&nbsp;');
  li.append('&nbsp;');
  li.append(ts).wrap('<p>');
  li.append('&nbsp;=&nbsp;');
  li.append(vs);
  li.append('&nbsp;&nbsp;');

  $("#tagselectlist").append(li);
};

var addParameter = function(url, key, value) {
  var a = url.split('?');
  if (a.length > 1) {
    return url + '&' + key + '=' + value;
  } else {
    return url + '?' + key + '=' + value;
  }
};

var layerSelect = function (categorySelect) {
  var attribute = 'category';
  var category = categorySelect.value;
  var uri = URI().removeSearch(attribute);
  if (category !== 'all') {
    uri.addSearch(attribute, category);
  }
  document.location = uri.toString();
};

var deleteLayer = function (name) {
  var confirmed = confirm(
    'Are you sure you want to delete the ' + name + ' layer?'
  );

  if (!confirmed) {
    return;
  }

  $.ajax({
    url: '/layers/' + name + '/',
    type: 'delete',
    success: function () {
      window.location.reload();
    }
  });
};

var fileUpload = function (layer_name, u) {
  var data = new FormData();
  jQuery.each($("input[type='file']")[0].files, function (i, file) {
    data.append(i, file);
  });
  $.ajax({
    type: 'post',
    data: data,
    url: '/layers/' + layer_name + '/data',
    cache: false,
    contentType: false,
    processData: false,
    success: function(data) {
      $(u).html(data);
    },
    error: function (jqXHR, textStatus, errorThrown ) {
      $(u).html(errorThrown + '<br/>' + jqXHR.responseText);
    }
  });
};

var unloadPrefixes = function() {
  $('#prefix').hide();
  $('#mappings').show();
};

var loadPrefixes = function() {
  $('#prefix').load('/prefixes', function() {
    $('#mappings').hide();
    $('#prefix').show();
  });
};

var saveLayerProperties = function (layerid) {
  var ldata = {
    "props": $.layerProperties,
    "type": $("#layer_type").val()
  };

  if ($.selectedField != undefined) {
    loadFieldDef($.selectedField);
  }

  $.post(
    "/layer/" + layerid + "/ldprops",
    JSON.stringify(ldata),
    function (data, textStatus, jqXHR) {
      $("#was_saved").show();
      setTimeout(
        function () {
          $("#was_saved").hide();
        },
        2000
      );
    }
  );
};

var loadFieldDef = function(field) {
  if ($.selectedField != undefined ) {
    if (!$.layerProperties[$.selectedField]) {
      $.layerProperties[$.selectedField] = {};
    }

    $.layerProperties[$.selectedField].descr = $("#relation_desc").val();
    $.layerProperties[$.selectedField].type  = $("#relation_type").val();
    $.layerProperties[$.selectedField].lang  = $("#relation_lang").val();
    $.layerProperties[$.selectedField].unit  = $("#relation_unit").val();
    $.layerProperties[$.selectedField].eqprop = $("#relation_ep").val();
  }

  $("#pname").html(field);

  if ($.layerProperties[field] != undefined) {
    $("#relation_desc").val($.layerProperties[field].descr);
    $("#relation_type").val($.layerProperties[field].type);
    $("#ptype").val($.layerProperties[field].type.substring(4));
    $("#relation_lang").val($.layerProperties[field].lang);
    $("#relation_unit").val($.layerProperties[field].unit);
    $("#relation_ep").val($.layerProperties[field].eqprop);
  } else {
    $("#relation_ep").val('');
    $("#relation_desc").val('');
    $("#relation_type").val('xsd:string');
    $("#ptype").val('string');
    $("#relation_lang").val('@en');
    $("#relation_unit").val('Count');
  }

  $.selectedField = field;

  if ($.layerProperties[field]
      && ($.layerProperties[field].type == 'xsd:integer'
            || $.layerProperties[field].type == 'xsd:float')) {
    $("#relationunit").show();
    $('#relation_unit').autocomplete({
      source: function (request, response) {
        var matcher = new RegExp(
          "^" + $.ui.autocomplete.escapeRegex( request.term ),
          "i"
        );
        response($.grep($.units, function (item) {
          return matcher.test( item );
        }));
      }
    });
  } else {
    $("#relationunit").hide();
  }

  if ($.layerProperties[field].type == 'xsd:string'
      || $.layerProperties[field].type == 'string') {
    $("#relationlang").show();
  } else {
    $("#relationlang").hide();
  }
};

var selectEqProperty = function(s) {
  if (s != 'select...') {
    $("#relation_ep").val(s);
    $("#ptype").val($.eqProperties[s]);
    selectFieldType($.eqProperties[s]);
  } else {
    $("#relation_ep").val('')
  }
};

var selectFieldType = function (s) {
  field = $("#pname").val();

  if ($.layerProperties[field]
      && $.layerProperties[field].type
      && $.layerProperties[field].type != '') {
    $("#relation_type").val($.layerProperties[field].type);
  } else {
    $("#relation_type").val(propertyTypes[s]);
  }

  if (s == 'integer' || s == 'float') {
    $("#relationunit").show()
    $('#relation_unit').autocomplete({
      source: function (request, response) {
        var matcher = new RegExp(
          "^" + $.ui.autocomplete.escapeRegex( request.term ),
          "i"
        );
        response(
          $.grep($.units, function (item) {
            return matcher.test( item );
          })
        );
      }
    });
  } else {
    $("#relationunit").hide();
  }

  if (s == 'string') {
    $("#relationlang").show();
  } else {
    $("#relationlang").hide();
  }
};

var delPrefix = function(s) {
  $.ajax({
    url: '/prefix/' + s,
    type: 'delete',
    success: function(data){
      $('#prefix').html(data);
    }
  });
};

var addPrefix = function() {
   var url = '/prefixes?prefix='
   url = url + $("#prefix_pfx").val();
   url = url + '&name=';
   url = url + $("#prefix_nme").val();
   url = url + '&uri=';
   url = url + encodeURIComponent($("#prefix_uri").val());
   $('#prefix').load(url);
};

var selectFieldTags = function(layer, fieldselect) {
  if (availableTags[layer] != null) {
    $('#ldmap')
      .prepend(
        $('<select id="'
          + fieldselect
          + '" name="field" onchange="loadFieldDef(this.value)"></select>'
        )
        .append(optionsForSelect(availableTags[layer], false))
      );
    $("#pname").html(availableTags[layer][0]);
    loadFieldDef(availableTags[layer][0]);
    return;
  }

  $.ajax({
    url: '/layers/' + layer + ' /keys',
    type: 'get',
    success: function(data) {
      obj = $.parseJSON(data)
      availableTags[layer] = obj
      return selectFieldTags(layer,fieldselect)
    }
  });
};

