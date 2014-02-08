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
      @original_file = p.fetch(:filename)
      if p.nil? || p[:tempfile].nil?
        return
      end

      @layerSelect = Layer.selectTag()
      tmp_file_dir = CONFIG.get('cms_tmp_file_dir')
      parseUploadedFile(p[:tempfile], @layer.name,tmp_file_dir)
    end # do
  end # class
end # module

