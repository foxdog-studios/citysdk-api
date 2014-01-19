require 'base64'
require 'json'
require 'logger'
require 'tmpdir'

require 'sequel'
require 'trollop'

require 'citysdk'

IMPORT_PERIODS = ['hourly', 'daily', 'weekly', 'monthly']


opts = Trollop::options do
  banner <<-EOS
	Imports periodic data. These are URLs that have been set through the CMS that
	point to data that is to be imported at certain intervals (hourly, daily,
	weekly and monthly). Use the CMS to set these up.

  EOS
  opt :email, 'CitySDK user email address', :type => :string, :required => true
  opt :password, 'CitySDK user password', :type => :string, :required => true
  opt(:host,
      'CitySDK API endpoint host (inc. port if not 80)',
      :type => :string,
      :required => true)
  opt(:dbconfig,
      'File path to CitySDK Database config',
      :type => :string,
      :required => true)
  opt(:period,
      'Import data for layers at this period. Accepted values:' \
      " #{IMPORT_PERIODS.join(', ')}.",
      :type => :string,
      :required => true)
end

unless File.exists?(opts[:dbconfig])
  Trollop::die(:dbconfig,
               "db config file does not exist at #{opts[:dbconfig]}")
end

unless IMPORT_PERIODS.include? opts[:period]
  Trollop::die(:period, "Must be one of: #{IMPORT_PERIODS.join(', ')}")
end


$logger = Logger.new(STDOUT)

$email = opts[:email]
$passw = opts[:password]
$host  = opts[:host]
$import_period = opts[:period]


def import_file(file_path, params)
  params[:file_path] = file_path
  params[:email] = $email
  params[:passw] = $passw
  params[:host]  = $host

  fileReader = CitySDK::FileReader.new(params)
  # XXX: Have to call this or entries won't be marked with ids.
  fileReader.findUniqueField
  fileReader.write(file_path)
  params[:file_path] = file_path + '.csdk'
  params[:fields] = params[:fields].map { |f| f.to_sym }

  $logger.info("Importing layer: #{params[:layername]} file: #{file_path}")
  importer = CitySDK::Importer.new(params)
  # TODO: Set the layer status
  importResults = importer.doImport
  $logger.info importResults
end


def import_layer_periodic_data(layer)
  params = JSON.parse(Base64::decode64(layer.import_config),
                     {:symbolize_names => true} )
  Dir.mktmpdir {|dir|
    if system "wget -P #{dir} '#{layer.import_url}'"
      Dir.open(dir).each do |file_path|
        next if file_path =~ /^\./
        import_file(dir + "/" + file_path, params)
        return true
      end
    end
  }
rescue Exception => e
  $logger.error "#{e.class} (#{e.message}):\n  #{e.backtrace.join("\n  ")}"
  return false
end


dbconf = JSON.parse(File.read(opts[:dbconfig]))

Sequel.connect(
  :adapter => 'postgres',
  :host => dbconf['db_host'],
  :database => dbconf['db_name'],
  :user => dbconf['db_user'],
  :password => dbconf['db_pass'])


class Layer < Sequel::Model
end


layers = Layer.where(:import_period => $import_period).all
$logger.info "Number of #{$import_period} layers: #{layers.count}"

layers.each do |layer|
  next if layer.import_config.nil? or layer.import_url.nil?

  import_url = layer.import_url
  lastModified = `curl --silent --head '#{import_url}' | grep Last-Modified`

  # Match string in the format
  # "Last-Modified: Mon, 13 Jan 2014 14:33:41 GMT"
  if lastModified =~ /.*,\s+(.*\s+\d\d:\d\d:\d\d)/
    # Value in $1 should be in the format
    # "13 Jan 2014 14:33:41"
    lastModified = $1
    requireUpdate = true
    lastModifiedDateTime = DateTime.parse(lastModified)
    if layer.imported_at
      lastImportedDateTime = DateTime.parse(layer.imported_at.to_s)
      if lastModifiedDateTime <= lastImportedDateTime
        requireUpdate = false
      end
    end
    if requireUpdate
      if import_layer_periodic_data(layer)
        layer.imported_at = $1
        layer.save
      end
    else
      $logger.info 'Last-modified not changed. No update occured'
    end
  else
    $logger.warn 'Last-modified did not match regex. No update occured'
  end
end

