module Sprig
  module Seed
    class Entry
      class UnknownAttributeError < StandardError; end

      attr_reader :klass

      def initialize(klass, attrs, options)
        self.klass = klass
        attrs = attrs.to_hash.with_indifferent_access
        self.sprig_id = attrs.delete(:sprig_id) || SecureRandom.uuid
        @attributes = AttributeCollection.new(attrs)
        @options = options
      end

      def dependencies
        @dependencies ||= attributes.map do |attribute|
          attribute.dependencies
        end.flatten.uniq
      end

      def dependency_id
        @dependency_id ||= Dependency.for(klass, sprig_id).id
      end

      def before_save
        # TODO: make these filters take chains like rails before_filters
        if options[:delete_existing_by]
          klass.where(options[:delete_existing_by] => attribute_value_for(options[:delete_existing_by])).delete_all
        end
      end

      def save_record
        record.save
      end

      def save_to_store
        SprigRecordStore.instance.save(record.orm_record, sprig_id)
      end

      def in_progress_text
        "Planting #{klass.name} with sprig_id #{sprig_id}"
      end

      def success_log_text
        if record.existing?
          "Updated"
        else
          "Saved"
        end
      end

      def error_log_text
        "There was an error saving #{klass.name} with sprig_id #{sprig_id}."
      end

      def success_summary_text
        "#{klass.name} with sprig_id #{sprig_id} (#{success_log_text})"
      end

      def record
        @record ||= new_or_existing_record
      end

      private

      attr_reader :attributes, :options, :sprig_id

      def klass=(klass)
        raise ArgumentError, "First argument must be a Class" unless klass.is_a?(Class)

        @klass = klass
      end

      def sprig_id=(sprig_id)
        @sprig_id = sprig_id.to_s
      end

      def new_or_existing_record
        if options[:find_existing_by]
          Record.new_or_existing(klass, attributes, find_existing_params)
        else
          Record.new(klass, attributes)
        end
      end

      def find_existing_params
        Array(options[:find_existing_by]).inject({}) do |hash, attribute_name|
          hash.merge!(
            {attribute_name => attribute_value_for(attribute_name)}
          )
        end
      end

      def attribute_value_for(attribute_name)
        validate_attribute_defined!(attribute_name)

        attributes.find_by_name(attribute_name).value
      end

      def validate_attribute_defined!(attribute_name)
        return if klass.new.respond_to?(attribute_name.to_s)

        raise UnknownAttributeError,
          "'#{attribute_name}' is not a valid attribute for #{klass.name}. " \
          "find_existing_by/delete_existing_by must reference an attribute defined on the class."
      end
    end
  end
end
