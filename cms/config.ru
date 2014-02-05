require './csdk_cms'
use Rack::Static, root: 'public', urls: %w(/css /script)
run CSDK_CMS

