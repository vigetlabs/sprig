module Sow
  module Dependency
    class Sorter
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

      class MissingDependencyError < StandardError
        attr_reader :original
        def initialize(msg, original=nil);
          super(msg);
          @original = original;
        end
      end

      class CircularDependencyError < StandardError
        attr_reader :original
        def initialize(msg, original=nil);
          super(msg);
          @original = original;
        end
      end

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
        # match = /\[(?<entries>.*)\]/.match e.message
        # entries = match[:entries].gsub('"', '').split(', ')
        # sow_records = entries.map do |entry|
        #   entry_info = /^(?<table>[^\d]+)_(?<id>[\d]+)/.match entry
        #   "sow_record(#{entry_info[:table].classify}, #{entry_info[:id]})"
        # end
        # raise CircularDependencyError.new("#{sow_records} contain circular dependencies.", e)
        raise CircularDependencyError.new("Your sow directives contain circular dependencies. #{e.message}", e)
      end

      class TsortableHash < Hash
        include TSort

        alias tsort_each_node each_key

        def tsort_each_child(node, &block)
          fetch(node).each(&block)
        rescue KeyError => e
          node_info = /^(?<table>[^\d]+)_(?<id>[\d]+)/.match node

          # raise MissingDependencyError.new("No defined entry for 'sow_record(#{node_info[:table].classify}, #{node_info[:id]})'.", e)
          raise MissingDependencyError.new("Referenced 'sow_record' does not have a correlating record.", e)
        end
      end
    end
  end
end
