if ARGV[0]

  importData = nil

  begin

    require 'citysdk'

    puts "\nFile import at #{Time.now.strftime('%b %d %Y - %H:%M:%S')}"

    params = JSON.parse(ARGV[0], {:symbolize_names => true} )
    params[:fields] = params[:fields].map { |f| f.to_sym }

    puts "\tlayer: #{params[:layername]}\n\tfile: #{params[:originalfile]}"

    puts params

    importData = CitySDK::Importer.new(params)

    puts "beginning import"

    importData.setLayerStatus("importing...")

    ret = importData.doImport

    s = "updated: #{ret[:updated]}; added: #{ret[:created]}; not added: #{ret[:not_added]}"
    puts s

    importData.setLayerStatus(s)


  rescue Exception => e
    puts "Exiting due to exception"
    begin
        # XXX: HACK TO GET STOP FLUSH
        importData.clear_nodes
        importData.sign_out
        importData.setLayerStatus(e.message)
    rescue Exception => e
        puts "Exception setting layer status"
        puts e.message
        puts e.backtrace
    end
    puts "Exception: #{e.message}"
    puts e.backtrace
  end

end


