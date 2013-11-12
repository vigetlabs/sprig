module Sow
  module Data
    class Source
      def initialize(table_name, options)
        @table_name = table_name.to_s
        options ||= {}
        self.source = options.fetch(:source) { default_source }
        self.parser = options.fetch(:parser) { default_parser }
      end

      def records
        data_hash[:records] || []
      end

      def options
        data_hash[:options] || {}
      end

      private

      attr_reader :parser, :source, :table_name

      def source=(source)
        raise ArgumentError, 'Data sources must act like an IO.' unless source.respond_to?(:read) && source.respond_to?(:close)

        @source = source
      end

      def parser=(parser)
        raise ArgumentError, 'Parsers must define #parse.' unless parser.method_defined?(:parse)

        @parser = parser
      end

      def default_source
        File.open(default_source_file)
      end

      def default_parser
        ParserDeterminer.new(default_source_file).parser
      end

      def default_source_file
        @default_source_file ||= SourceDeterminer.new(table_name).file
      end

      def data_hash
        @data_hash ||= convert_to_hash
      end

      def convert_to_hash
        parser.new(source).parse.to_hash.with_indifferent_access
      ensure
        cleanup
      end

      def cleanup
        source.close
      end

      class SourceDeterminer
        attr_reader :table_name

        def initialize(table_name)
          @table_name = table_name
        end

        def file
          File.new(seed_directory.join(filename))
        end

        private

        class FileNotFoundError < StandardError; end

        def filename
          available_files.detect {|name| name =~ /^#{table_name}\./ } || file_not_found
        end

        def available_files
          Dir.entries(seed_directory)
        end

        def file_not_found
          raise FileNotFoundError, "No datasource file could be found for '#{table_name}'. Try creating #{table_name}.yml, #{table_name}.json, or #{table_name}.csv within #{seed_directory}, or define a custom datasource."
        end
      end

      class ParserDeterminer
        def initialize(file)
          @file = file
        end

        def parser
          match = parser_matchers.detect {|p| p[:extension] =~ extension } || unparsable_file
          match[:parser]
        end

        private

        class UnparsableFileError < StandardError; end

        attr_reader :file

        def extension
          File.extname(file)
        end

        def parser_matchers
          [
            {
              extension: /\.y(a)?ml/i,
              parser: Sow::Data::Parser::Yml
            },
            {
              extension: /\.json/i,
              parser: Sow::Data::Parser::Json
            },
            {
              extension: /\.csv/i,
              parser: Sow::Data::Parser::Csv
            }
          ]
        end

        def parsable_formats
          ['YAML', 'JSON', 'CSV']
        end

        def unparsable_file
          raise UnparsableFileError, "No parser was found for the file '#{file}'. Provide a custom parser, or use a supported data format (#{parsable_formats})."
        end
      end
    end
  end
end
