if ARGV[0]

  importData = nil

  begin

    require 'citysdk'

    puts "\nFile import at #{Time.now.strftime('%b %d %Y - %H:%M:%S')}"

    params = JSON.parse(ARGV[0], {:symbolize_names => true} )
    params[:fields] = params[:fields].map { |f| f.to_sym }

    puts "\tlayer: #{params[:layername]}\n\tfile: #{params[:originalfile]}"

    # puts "params: #{JSON.pretty_generate(params)}"


    importData = CitySDK::Importer.new(params)

    importData.setLayerStatus("importing...")

    ret = importData.doImport

    s = "updated: #{ret[:updated]}; added: #{ret[:created]}; not added: #{ret[:not_added]}"
    puts s

    csv.setLayerStatus(s)


  rescue Exception => e
    importData.setLayerStatus(e.message) if importData
    puts "Exception: #{e.message}"
    puts e.backtrace
  end

end


