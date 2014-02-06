$LOAD_PATH.unshift File.dirname(__FILE__)

require 'base64'
require 'json'
require 'open-uri'

require 'sinatra'
require 'sinatra/sequel'
require 'sinatra/session'
require 'citysdk'


class Configuration
  def initialize(path)
    @config = open(path) { |config_file| JSON.load(config_file) }
  end # def

  def get(key, prefix = nil)
    key = "#{ prefix }_#{ key }" unless prefix.nil?
    @config.fetch(key)
  end # def

  def get_db(db_key)
    get(db_key, prefix = 'db')
  end # def

  def get_ep(ep_key)
    get(ep_key, prefix = 'ep')
  end # def
end # class

CONFIG = Configuration.new('config.json')


enable :sessions


configure do |app|
  if defined? PhusionPassenger
    PhusionPassenger.on_event(:starting_worker_process) do |forked|
      # Disconnect if we're in smart spawning mode.
      database.disconnect if forked
    end # do
  end # if

  user     = CONFIG.get_db('user')
  password = CONFIG.get_db('pass')
  host     = CONFIG.get_db('host')
  database = CONFIG.get_db('name')

  app.database = "postgres://#{ user }:#{ password }@#{ host }/#{ database }"
  app.database.extension :pg_array
  app.database.extension :pg_range

  DB = app.database

  root_path = Pathname.new(__FILE__).dirname
  Dir[root_path.join('utils/*.rb')].each { |file| require file }
  Dir[root_path.join('models/*.rb')].each { |file| require file }

  require 'sinatra-authentication'
end # do


class CSDK_CMS < Sinatra::Base
  set :template_engine, :erb
  Sinatra::SinatraAuthentication.registered(self)

  set :views, Proc.new { File.join(root, '../views') }

  use Rack::MethodOverride
  register Sinatra::Session
  set :session_expire, 60 * 60 * 24
  set :session_fail, '/login'
  set :session_secret, CONFIG.get('session_secret')


  def self.do_abort(code,message)
    throw(:halt, [code, {'Content-Type' => 'text/plain'}, message])
  end

  before do
    @api_server = CONFIG.get_ep('api_url')
    @sample_url = CONFIG.get_ep('info_url') + "/map#http://#{@api_server}/"

  end # do

  def get_layers
    @layerSelect = Layer.selectTag()
    @selected = params[:category] || 'administrative'
    ds = Layer
    if @selected != 'all'
      ds = ds.where(Sequel.like(:category, "#{ @selected }%"))
    end # if
    @layers = ds.order(:name).all
  end

  get '/' do
    get_layers
    erb :layers, :layout => @nolayout ? false : true
  end

  get '/layers' do
    get_layers
    erb :layers, :layout => @nolayout ? false : true
  end

  get '/get_layer_keys/:layer' do |layer_name|
    layer = Layer.where(name: layer_name).first
    return '{}' if layer.nil?

    sql = "select keys_for_layer(#{ layer.id })"
    keys = Sequel::Model.db.fetch(sql).all

    api = CitySDK::API.new(@api_server)
    ml = api.get("/nodes?layer=#{ layer_name }&per_page=1")

    if ml[:status] == 'success' && ml[:results][0]
      h = ml[:results][0][:layers][layer_name.to_sym][:data]
      h.each_key { |key| keys[0][:keys_for_layer] << key.to_s }
    end # if

    keys[0][:keys_for_layer].uniq.to_json
  end

  get '/get_layer_stats/:layer' do |l|
    l = Layer.where(name: l).first
    @lstatus = l.import_status || '-'
    @ndata   = NodeData.where(:layer_id => l.id).count
    @ndataua = NodeData.select(:updated_at).where(:layer_id => l.id).order(:updated_at).reverse.limit(1).all
    @ndataua = ( @ndataua and @ndataua[0] ) ? @ndataua[0][:updated_at] : '-'
    @nodes   = Node.where(:layer_id => l.id).count
    @delcommand = "delUrl('/layer/" + l.id.to_s + "',null,$('#stats'))"
    erb :stats, :layout => false
  end

  get '/layer/:layer_id/data' do |layer_id|
    login_required

    @layer = Layer[layer_id]
    if @layer.nil? || current_user.id != @layer.owner_id || !current_user.admin?
      halt 401, 'Not authorized'
    end # if

    @period = @layer.period_select()
    @props = {}

    LayerProperty.where(:layer_id => layer_id).each do |property|
      @props[property.key] = property.serialize
    end # do

    @langSelect  = Layer.languageSelect
    @ptypeSelect = Layer.propertyTypeSelect
    @lType = @layer.rdf_type_uri
    @epSelect,@eprops = Layer.epSelect
    @props = @props.to_json

    if params.fetch(:nolayout)
      erb :layer_data, layout: false
    else
      erb :layer_data
    end
  end

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

  post '/layer/:layer_id/webservice' do |l|
    if Owner.valid_session(session[:auth_key])
      @layer = Layer[l]
      if(@layer && (@oid == @layer.owner_id) or @oid==0)
        @layer.webservice = params['wsurl']
        @layer.update_rate = params['update_rate']
        if !@layer.valid?
          @categories = @layer.cat_select
          redirect "/layer/#{l}/data"
        else
          @layer.save
          redirect "/layer/#{l}/data"
        end
      end
    end
  end

  post '/layer/:layer_id/periodic' do |l|
    if Owner.valid_session(session[:auth_key])
      @layer = Layer[l]
      if(@layer && (@oid == @layer.owner_id) or @oid==0)
        @layer.import_url = params['update_url']
        @layer.import_period = params['period']
        if !@layer.valid? or @layer.import_config.nil?
          @categories = @layer.cat_select
          redirect "/layer/#{l}/data"
        else
          @layer.save
          redirect "/layer/#{l}/data"
        end
      end
    end
  end


  get '/layer/:layer_id/edit' do |l|
    if Owner.valid_session(session[:auth_key])
      @layer = Layer[l]
      if(@layer && (@oid == @layer.owner_id) or @oid==0)
        @layer.data_sources = [] if @layer.data_sources.nil?
        @categories = @layer.cat_select
        @webservice = @layer.webservice and @layer.webservice != ''
        erb :edit_layer
      else
        CSDK_CMS.do_abort(401,"not authorized")
      end
    else
      redirect '/'
    end
  end


  get '/prefixes' do
    if Owner.valid_session(session[:auth_key])
      if params[:prefix] and params[:name] and params[:uri]
        if params[:prefix][-1] != ':'
          params[:prefix] = params[:prefix] + ':'
        end
        pr = LDPrefix.new( {
          :prefix => params[:prefix],
          :name => params[:name],
          :url => params[:uri],
          :owner_id => @oid
        })
        pr.save
      end

      @prefixes = LDPrefix.order(:name).all
      erb :prefixz, :layout => false
    else
      redirect '/'
    end
  end

  delete '/prefix/:pr' do |p|
    if Owner.valid_session(session[:auth_key])
      LDPrefix.where({:owner_id=>@oid, :prefix=>p}).delete
    end
    @prefixes = LDPrefix.order(:name).all
    erb :prefixz, :layout => false
  end

  delete '/layer/:layer_id' do |l|

    if Owner.valid_session(session[:auth_key])
      @layer = Layer[l]
      if(@layer && (@oid == @layer.owner_id) or @oid==0)
        url = "/layer/#{@layer.name}"
        par = []
        params.each_key do |k|
          par << "#{k}=#{params[k]}"
        end
        url += "?" + par.join("&") if par.length > 0
        begin
          api = CitySDK::API.new(@api_server)
          api.authenticate(session[:e],session[:p]) do
            api.delete(url)
          end
        rescue Exception => e
          @errorContext = "delete layer #{@layer.name}:"
          @errorMessage = e.message
          puts "deleting content of #{@layer.name}, error: #{e.message}\n #{e.backtrace}"
          return "deleting content of #{@layer.name}, error: #{e.message}" + @errorMessage
        end
      end
    end
    get_layers
    redirect "/"
  end

  get '/layer/new' do
    if Owner.valid_session(session[:auth_key])
      @owner = Owner[@oid]
      if @oid != 0
        domains = @owner.domains.split(',')
        if( domains.length > 1 )
          @prefix  = "<select name='prefix'> "
          domains.uniq.each do |p|
            @prefix += "<option>#{p}</option>"
          end
          @prefix += "</select>"
        else
          @prefix = domains[0]
        end
      end
      @layer = Layer.new
      @layer.data_sources = []
      @layer.update_rate = 3600
      @layer.organization = @owner.organization
      @categories = @layer.cat_select
      @webservice = false
      erb :new_layer
    else
      CSDK_CMS.do_abort(401,"not authorized")
    end
  end

  post '/layer/create' do
    if Owner.valid_session(session[:auth_key])

      puts JSON.pretty_generate(params)

      @layer = Layer.new
      @layer.owner_id = @oid

      if( params['prefix'] && params['prefix'] != '' )
        @layer.name = params['prefix'] + '.' + params['name']
      elsif (params['prefixc']  && params['prefixc'] != '' )
        @layer.name = params['prefixc'] + '.' + params['name']
      else
        @layer.name = params['name']
      end

      params['validity_from'] = Time.now.strftime('%Y-%m-%d') if params['validity_from'].nil?
      params['validity_to'] = Time.now.strftime('%Y-%m-%d') if params['validity_to'].nil?

      @layer.description = params['description']
      @layer.update_rate = params['update_rate'].to_i
      @layer.validity = "[#{params['validity_from']}, #{params['validity_to']}]"
      @layer.realtime = params['realtime'] ? true : false;
      @layer.data_sources = []
      @layer.data_sources << params["data_sources_x"] if params["data_sources_x"] && params["data_sources_x"] != ''
      @layer.organization = params['organization']
      @layer.category = params['catprefix'] + '.' + params['category']
      @layer.webservice = params['wsurl']
      @layer.update_rate = params['update_rate']

      if !@layer.valid?
        @prefix = params['prefixc']
        @layer.name = params['name']
        @categories = @layer.cat_select
        erb :new_layer
      else
        @layer.save
        get_layers
        erb :layers
      end
    end
  end

  post '/layer/edit/:layer_id' do |l|
    if Owner.valid_session(session[:auth_key])
      @layer = Layer[l]
      if(@layer && (@oid == @layer.owner_id) or @oid==0)
        @layer.description = params['description']
        params['validity_from'] = Time.now.strftime('%Y-%m-%d') if params['validity_from'].nil?
        params['validity_to'] = Time.now.strftime('%Y-%m-%d') if params['validity_to'].nil?
        if( params['realtime'] )
          @layer.realtime = true;
          @layer.update_rate = params['update_rate'].to_i
        else
          @layer.realtime = false;
          @layer.validity = "[#{params['validity_from']}, #{params['validity_to']}]"
        end
        ds = []; i = 0;
        while params["data_sources"][i.to_s]
          if params["data_sources"][i.to_s] != ''
            ds << params["data_sources"][i.to_s]
          end
          i += 1
        end if params["data_sources"]
        ds << params["data_sources_x"] if params["data_sources_x"] && params["data_sources_x"] != ''
        @layer.data_sources = ds
        @layer.organization = params['organization']
        @layer.category = params['catprefix'] + '.' + params['category']

        @layer.webservice = params['wsurl']
        @layer.update_rate = params['update_rate']

        @layer.sample_url = params['sample_url'] if params['sample_url'] and params['sample_url'] != ''


        if !@layer.valid?
          @categories = @layer.cat_select
          erb :edit_layer
        else
          @layer.save
          api = CitySDK::API.new(@api_server)
          api.get('/layers/reload__')
          redirect '/'
        end
      else
        CSDK_CMS.do_abort(401,"not authorized")
      end
    else
      redirect '/'
    end
  end


  post '/layer/:layer_id/upload_file' do |layer_id|
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

  get '/fupl/:layer' do |layer|
    @layer = Layer[layer]
    erb :file_upl, :layout => false
  end


  post '/uploaded_file_headers' do
    if params['add']

      parameters = JSON.parse(Base64.decode64(params['parameters']),
                              {:symbolize_names => true})
      params.delete('parameters')
      parameters = parameters.merge(params)

      parameters.each do |k,v|
        parameters.delete(k) if v =~ /^<no\s+/
      end

      parameters[:host] = @api_server
      parameters[:email] = session[:e]
      parameters[:passw] = session[:p]

      import_log_path = $config['cms_import_log_path']
      parameters_json = parameters.to_json
      import_file_command = "ruby utils/import_file.rb '#{parameters_json}'"
      import_log_command = "#{import_file_command} >> #{import_log_path} &"
      puts "RUNNING IMPORT COMMAND: #{import_log_command}"
      system import_log_command

      parameters.delete(:email)
      parameters.delete(:passw)
      parameters.delete(:file_path)
      parameters.delete(:originalfile)

      api = CitySDK::API.new(@api_server)
      puts JSON.pretty_generate(parameters)

      api.authenticate(session[:e], session[:p]) do
        d = { :data => Base64.encode64(parameters.to_json) }
        api.put("/layer/#{parameters[:layername]}/config",d)
      end

      redirect "/get_layer_stats/#{parameters[:layername]}"
    else
      a = matchCSV(params)
      a = JSON.pretty_generate(a)
      return [200, {} ,"<hr/><pre>#{ a }</pre>"]
    end # else
  end # do
end # class
