class CitySDKAPI < Sinatra::Base

  module PolygonMatcher
    
    def self.match(node, params)
      return nil, nil, nil, false
    end
        
  end  
  
end
