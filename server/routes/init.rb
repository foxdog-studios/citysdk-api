# encoding: utf-8

require_relative 'get'

require_relative 'layer/get'
require_relative 'layer/delete'
require_relative 'layer/config/put'
require_relative 'layer/status/put'

require_relative 'layers/get'
require_relative 'layers/put'

require_relative 'nodes/get'
require_relative 'nodes/layer/put'
require_relative 'ptlines/get'

require_relative 'ptstops/get'

require_relative 'regions/get'

require_relative 'routes/get'

require_relative 'util/match/post'

require_relative 'within/nodes/get'
require_relative 'within/ptlines/get'
require_relative 'within/ptstops/get'
require_relative 'within/regions/get'
require_relative 'within/routes/get'

# Node routes must be requested last because of the ambiguous URL scheme.
require_relative 'node/get'
require_relative 'node/layer/get'
require_relative 'node/layer/delete'
require_relative 'node/layer/put'
require_relative 'node/select/cmd/get'

