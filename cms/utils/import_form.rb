# -*- encoding: utf-8 -*-

module CitySDK
  class ImportForm
    def self.update(import, params)
      self.new(import, params)
      import
    end # def

    private

    # The fields here must match the input names in the template and
    # the name of the attribute on the Layer model.
    FIELDS = %i(
      min_period
      url
      format
      id_field
      name_field
      latitude_field
      longitude_field
    )

    def initialize(import, params)
      @import = import
      @params = params
      update
    end # def

    def update
      FIELDS.each &method(:update_if)
    end # def

    # Update the field `name` on `@import` if `name` is present in
    # `@params`.
    def update_if(name)
      text = @params[name]
      @import.send("#{name}=", clean(text)) if text
    end # def

    def clean(text)
      stripped = text.strip
      stripped.empty? ? nil : stripped
    end # def
  end # class
end # module

