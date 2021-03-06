# encoding: utf-8

NODE_NAME_NODE   = 'node'.freeze()
NODE_NAME_ROUTE  = 'route'.freeze()
NODE_NAME_PTSTOP = 'ptstop'.freeze()
NODE_NAME_PTLINE = 'ptline'.freeze()

NODE_TYPE_NODE   = 0
NODE_TYPE_ROUTE  = 1
NODE_TYPE_PTSTOP = 2
NODE_TYPE_PTLINE = 3

NODE_TYPES_TO_NAME = {
  NODE_TYPE_NODE   => NODE_NAME_NODE,
  NODE_TYPE_ROUTE  => NODE_NAME_ROUTE,
  NODE_TYPE_PTSTOP => NODE_NAME_PTSTOP,
  NODE_TYPE_PTLINE => NODE_NAME_PTLINE
}.freeze()

NODE_NAMES_TO_TYPE = {
  NODE_NAME_NODE    => NODE_TYPE_NODE,
  NODE_NAME_ROUTE   => NODE_TYPE_ROUTE,
  NODE_NAME_PTSTOP  => NODE_TYPE_PTSTOP,
  NODE_NAME_PTLINE  => NODE_TYPE_PTLINE
}.freeze()


