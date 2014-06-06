module Sprig
  module Harvest
    class ModelConfig
      attr_reader :klass

      def initialize(klass, config = {})
        self.klass = klass

        @config = config
      end

      def klass=(given_class)
        unless Sprig::Harvest::Configuration::VALID_CLASSES.include? given_class
          raise ArgumentError, "Cannot create a seed file for #{given_class} because it is not a subclass of ActiveRecord::Base."
        end

        @klass = given_class
      end

      def collection
        @collection ||= config.fetch(:collection, klass.all)
      end

      def limit
        @limit ||= config.fetch(:limit, Sprig::Harvest.limit)
      end

      def ignored_attrs
        @ignored_attrs ||= (Array(config[:ignored_attrs]).map(&:to_s) + Sprig::Harvest.ignored_attrs).uniq
      end

      def attributes
        @attributes ||= klass.column_names - ignored_attrs
      end

      def dependencies
        @dependencies ||= klass.reflect_on_all_associations(:belongs_to).map do |association|
          association.name.to_s.classify.constantize
        end
      end

      private

      attr_reader :config
    end
  end
end
