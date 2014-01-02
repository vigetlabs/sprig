module Sow
  class DependencySorter
    class CircularDependencyError < StandardError; end
    class MissingDependencyError < StandardError; end

    attr_reader :items

    def initialize(items)
      @items = items.to_a
    end

    def sorted_items
      sorted_tags.map do |tag|
        id_dictionary[tag]
      end
    end

    private

    def id_dictionary
      @id_dictionary ||= begin
        {}.tap do |hash|
          items.each do |item|
            hash[item.dependency_id] = item
          end
        end
      end
    end

    def dependency_hash
      @dependency_hash ||= begin
        TsortableHash.new.tap do |hash|
          items.each do |item|
            hash[item.dependency_id] = item.dependencies.map(&:id)
          end
        end
      end
    end

    def sorted_tags
      dependency_hash.tsort
    rescue TSort::Cyclic => e
      raise CircularDependencyError.new("Your sow directives contain circular dependencies. #{e.message}", e)
    end

    class TsortableHash < Hash
      include TSort

      alias tsort_each_node each_key

      def tsort_each_child(node, &block)
        fetch(node).each(&block)
      rescue KeyError => e
        raise MissingDependencyError.new("Referenced 'sow_record' does not have a correlating record.", e)
      end
    end
  end
end
