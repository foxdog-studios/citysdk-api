# encoding: utf-8

module CitySDK
  class Layer < Sequel::Model
    many_to_one :owner, class: SequelUser
    plugin :validation_helpers

    @@eq_properties = {
     'rdfs:description' => 'string',
     'rdfs:label' => 'string',
     'rdfs:comment' => 'string',
     'dc:date' => 'dateTime',
     'dc:title' => 'string',
     'dc:creator' => 'string',
     'dc:identifier' => 'string'
    }

    def validate
      super
      validates_presence [:name, :description, :organization, :category]
      validates_unique :name
      validates_format /^\w+(\.\w+)*$/, :name
      validates_format /^\w+\.\w+$/, :category
      if (import_config.nil? or import_config=='') and import_url != nil
        errors.add(:import_url,"Cannot be set without config. Upload file once, first.")
      end
    end

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

    def self.category_select(sel=false, all=false)
      s= all ?
        "<select name='catprefix' onchange='layerSelect(this)'> " :
        "<select name='catprefix'> "

      s += "<option #{sel=='all' ? 'selected="selected"' : ''}>all</option>" if all
      sel = 'administrative' if sel==false

      Category.order(:name).all.each do |c|
        s += "<option #{c.name==sel ? 'selected="selected"' : ''}>#{c.name}</option>"
      end
      s += "</select>"
      s
    end

    def period_select()
      period  = "<select name='period'> "
      ['never','monthly','weekly','daily','hourly'].each do |p|
        if import_period == p
          period += "<option selected='selected'>#{p}</option>"
        else
          period += "<option>#{p}</option>"
        end
      end
      period += "</select>"
      period
    end # def

    def cat_select
      self.category = '.' if self.category.nil?
      pref = self.category.split('.')[0]
      categories = Layer.category_select(pref)
      self.category = self.category.split('.')[1]
      return categories
    end # def

    def self.selectTag
      r = "<select>"
      Layer.order(:id).all do |l|
        r += "<option>#{l.name}</option>"
      end # do
      r += "</select>"
    end # end
  end # class
end # module

