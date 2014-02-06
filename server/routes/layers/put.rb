class CitySDKAPI < Sinatra::Application
  put '/layers/' do
    login_required
    json = JSON.parse(request.body.read)
    halt 422, 'Layer data missing' if json['data'].nil?
    data = json.fetch('data')
    domain = data.fetch('name').split('.')[0]
    user = current_user

    unless user.domains.include?(domain)
      halt 401, {
        error: "You cannot create a layer within the #{ domain.inspect } "
               "domain because you are not a member of it."
        }.to_json
    end # unless

    layer = Layer.new(data)
    halt 422, layer.errors.to_json unless layer.valid?
    layer.owner_id = user.id
    layer.save
    [200, { status: 'success' }.to_json]
  end # do
end # class

