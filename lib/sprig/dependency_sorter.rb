module Sprig
  class DependencySorter
    class CircularDependencyError < StandardError; end

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
      raise CircularDependencyError.new("Your sprig directives contain circular dependencies. #{e.message}")
    rescue KeyError => key_error
      raise missing_dependency_error_from_key_error(key_error)
    end

    def dependencies
      items.map(&:dependencies).flatten
    end

    def missing_dependency_error_from_key_error(key_error)
      key = key_error.message.match(/\Akey not found: "(.*)"\Z/)[1]
      missing_dependency = dependencies.detect { |item| item.id == key }
      MissingDependencyError.new(missing_dependency)
    end

    class MissingDependencyError < StandardError
      def initialize(missing_dependency = nil)
        super message_for(missing_dependency)
      end

      private

      def message_for(missing_dependency)
        if missing_dependency.is_a? Dependency
          "Undefined reference to '#{missing_dependency.sprig_record_reference}'"
        else
          "Referenced 'sprig_record' does not have a correlating record."
        end
      end
    end
  end
end
