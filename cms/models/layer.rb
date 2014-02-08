# encoding: utf-8

module CitySDK
  class Layer < Sequel::Model
    plugin :validation_helpers

    many_to_one :owner, class: SequelUser

    def validate
      super
      validates_presence [
        :name,
        :description,
        :organization,
        :category
      ]

      validates_unique :name
      validates_format /^\w+(\.\w+)*$/, :name
      validates_format /^\w+\.\w+$/, :category

      if (import_config.nil? || import_config.empty?) && !import_url.nil?
        errors.add(
          :import_url,
          'Cannot be set without config. Upload file once, first.'
        )
      end # if
    end # def

    def self.get_by_name(name)
      where(name: name).first
    end # def

    def self.get_layers_in_category(category)
      where(Sequel.like(:category, "#{ category }%"))
    end # def
  end # class

  # Everything Peter hasn't looked at yet.
  class Layer < Sequel::Model

    @@eq_properties = {
     'rdfs:description' => 'string',
     'rdfs:label' => 'string',
     'rdfs:comment' => 'string',
     'dc:date' => 'dateTime',
     'dc:title' => 'string',
     'dc:creator' => 'string',
     'dc:identifier' => 'string'
    }

    def fieldDefsSelect() end

    def self.epSelect()
      s = '<select style="border 0px;" id="eptype" onchange="selectEqProperty(this.value)">'
      s += "<option>select...</option>"
      @@eq_properties.each_key do |k|
        s += "<option>#{k}</option>"
      end
      s += '</select>'
      return s,@@eq_properties.to_json
    end

    def self.languageSelect()
      '<select style="border 0px;" id="relation_lang">
        <option value="">n/a</option>
        <option value="@ca">català</option>
        <option value="@de">deutsch</option>
        <option value="@el">ελληνικά</option>
        <option value="@en" selected = "selected">english</option>
        <option value="@es">español</option>
        <option value="@fr">français</option>
        <option value="@fy">frysk</option>
        <option value="@li">limburgs</option>
        <option value="@nl">nederlands</option>
        <option value="@pt">português</option>
        <option value="@fi">suomi</option>
        <option value="@sv">svenska</option>
        <option value="@tr">türkçe</option>
      </select>'
    end

    def self.propertyTypeSelect()
      s = '<select style="border 0px;" id="ptype" onchange="selectFieldType(this.value)">'
      %w{ anyURI base64Binary boolean date dateTime float integer string time }.each do |w|
        s += "<option>#{w}</option>"
      end
      s += '</select>'
    end

    def self.selectTag
      r = "<select>"
      Layer.order(:id).all do |l|
        r += "<option>#{l.name}</option>"
      end # do
      r += "</select>"
    end # end
  end # class
end # module

