module Sprig
  class TsortableHash < Hash
    include TSort

    alias_method :tsort_each_node, :each_key

    def tsort_each_child(node, &block)
      fetch(node).each(&block)
    end
  end
end
