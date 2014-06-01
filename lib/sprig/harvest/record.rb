module Sprig
  module Harvest
    class Record
      attr_reader :record, :model
      attr_writer :sprig_id

      def initialize(record, model)
        @record = record
        @model  = model

        model.attributes.each do |attr|
          if dependency_finder.match(attr)
            eigenclass.instance_eval do
              define_method attr do
                klass    = klass_for(attr)
                id       = record.send(attr)
                sprig_id = Model.find(klass, id).sprig_id

                "<%= sprig_record(#{klass}, #{sprig_id}).id %>"
              end
            end
          else
            eigenclass.instance_eval do
              define_method attr do
                record.send(attr)
              end
            end
          end
        end
      end

      def attributes
        @attributes ||= Array.new.replace(model.attributes).tap do |attrs|
          attrs[0] = 'sprig_id'
        end
      end

      def to_hash
        attributes.reduce(Hash.new) { |hash, attr| hash.merge(attr => send(attr)) }
      end

      def sprig_id
        @sprig_id ||= model.existing_sprig_ids.include?(record.id) ? model.generate_sprig_id : record.id
      end

      private

      def eigenclass
        (class << self; self; end)
      end

      def dependency_finder
        /_id/
      end

      def klass_for(attr)
        attr.gsub(dependency_finder, '').classify.constantize
      end
    end
  end
end
