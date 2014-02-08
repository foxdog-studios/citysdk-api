# encoding: utf-8

module CitySDK
  class CMSApplication < Sinatra::Application
    post '/layers/:layer_id/upload' do |layer_id|
      login_required
      unless current_user.admin?
        halt 401, 'Not authorized'
      end

      @layer = Layer[layer_id]
      p = params['0'] || params.fetch('file')
      original_file_name = p.fetch(:filename)
      temp_file = p[:tempfile]
      if p.nil? || temp_file.nil?
        return
      end

      @layerSelect = Layer.selectTag()
      tmp_file_dir = CONFIG.fetch(:cms_tmp_file_dir)
      parseUploadedFile(temp_file, @layer.name, tmp_file_dir, original_file_name)
    end # do
  end # class
end # module

