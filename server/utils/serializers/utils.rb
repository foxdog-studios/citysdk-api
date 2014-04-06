# encoding: utf-8

module CitySDK
  def self.find_modality_names(ids)
    return [] if ids.nil?
    ids = ids.op()
    Modality.select(:name).where(id: ids.any()).map { |modality| modality.name }
  end # def
end # module
