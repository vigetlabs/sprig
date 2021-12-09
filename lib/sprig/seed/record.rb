module Sprig
  module Seed
    class Record
      attr_reader :orm_record

      delegate :errors, :to => :orm_record

      def self.new_or_existing(klass, attributes, find_params)
        orm_record = klass.where(find_params).first
        new(klass, attributes, orm_record)
      end

      def initialize(klass, attributes, orm_record = nil)
        @klass      = klass
        @attributes = attributes
        @orm_record = orm_record || klass.new
        @existing   = @orm_record.persisted?
      end

      def save
        populate_attributes
        orm_record.save
      end

      def existing?
        @existing
      end

      private

      attr_reader :attributes, :klass

      def populate_attributes
        attributes.each do |attribute|
          value = attribute.value

          relation = orm_record.class.reflect_on_all_associations.find{|a| a.name.to_s == attribute.name}
          if relation
            value = SprigRecordStore.instance.get(relation.klass, attribute.value)
          end

          orm_record.send(:"#{attribute.name}=", value)
        end
      end
    end
  end
end
