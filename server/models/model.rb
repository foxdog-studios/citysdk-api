# encoding: utf-8

class Sequel::Model
  @@node_types = ['node','route','ptstop','ptline']
  @@noderesults = []
  @@prefixes = Set.new
  @@layers = []
end # class

