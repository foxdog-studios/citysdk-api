# encoding: utf-8

require_relative 'get'

require_relative 'cdk_id/layer/delete'
require_relative 'cdk_id/layer/put'
require_relative 'cdk_id/select/cmd/get'

require_relative 'layer/get'
require_relative 'layer/delete'
require_relative 'layer/config/put'
require_relative 'layer/status/put'

require_relative 'layers/get'
require_relative 'layers/put'

# 'nodes' must be before node, otherwise 'node' captures the pathname /nodes/
# and trys to look up a node with cdk_id 'nodes'.
require_relative 'nodes/get'
require_relative 'nodes/layer/put'

require_relative 'node/get'
require_relative 'node/layer/get'

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

