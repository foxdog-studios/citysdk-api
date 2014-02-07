# encoding: utf-8

configure :development do
  use Rack::Static, root: 'public', urls: %w(/css /script)
end # do

