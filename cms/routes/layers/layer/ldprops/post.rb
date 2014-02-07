# encoding: utf-8

module CitySDK
  class CMSApplication < Sinatra::Application
    post '/layer/:layer_id/ldprops' do |layer_id|
      @layer = Layer[layer_id]
      if current_user.admin?
        request.body.rewind
        data = JSON.parse(request.body.read, symbolize_names: true)

        @layer.update(:rdf_type_uri=>data[:type])
        data = data[:props]

        data.each_key do |k|
          dk = data[k]
          if dk[:unit] != '' && dk[:unit] !~ /^csdk:unit/
            dk[:unit] = "csdk:unit#{dk[:unit]}"
          end # if

          p = LayerProperty.where(:layer_id => l, :key => k.to_s).first
          p = LayerProperty.new({:layer_id => l, :key => k.to_s}) if p.nil?
          p.type  = dk[:type]
          p.unit  = p.type =~ /^xsd:(integer|float)/ ? dk[:unit] : ''
          p.lang  = dk[:lang]
          p.descr = dk[:descr]
          p.eqprop = dk[:eqprop]

          unless p.save
            return [422, {}, 'error saving property data.']
          end # unless
        end # do
      end # if
    end # do
  end # class
end # module

