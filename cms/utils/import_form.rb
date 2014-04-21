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
    TEXT_FIELDS = %i(
      url
      format
      id_type
      id_text
      name_text
      name_type
      latitude_field
      longitude_field
    )

    def initialize(import, params)
      @import = import
      @params = params
      update
    end # def

    def update
      update_text
      update_max_frequency
    end # def

    def update_text
      TEXT_FIELDS.each &method(:update_text_if)
    end # def

    # Update the field `name` on `@import` if `name` is present in
    # `@params`.
    def update_text_if(name)
      text = @params[name]
      @import.send("#{name}=", clean(text)) if text
    end # def

    def update_max_frequency
      max_frequency = @params['max_frequency']
      return unless max_frequency
      max_frequency = clean(max_frequency)
      @import.max_frequency =
        if max_frequency == 'never'
          nil
        else
          begin
            Integer(max_frequency, 10)
          rescue ArgumentError
            return
          end # rescue
        end # else
    end # def

    def clean(text)
      stripped = text.strip
      stripped.empty? ? nil : stripped
    end # def
  end # class
end # module

