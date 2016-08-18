module Grnds
  module Ediot
    class Parser

      include SegmentParser

      DEFINITION = {
        INS: {size: 17 },
        REF: {occurs: 5, size: 2 },
        DTP: {occurs: 3, size: 3 },
        NM1: {occurs: 2, size: 9 },
        PER: {size: 8 },
        N3: {size: 2 },
        N4: {size: 3 },
        DMG: {size: 3 },
        HLH: {size: 3 },
        HD: {size: 5 },
        AMT: {size: 2 }
      }

      # @param definition [Hash{Symbol => Hash{Symbol => Number}}]
      def initialize(definition=DEFINITION)
        @record = Record.new(definition)
        @segment_keys = definition.keys.map{ |k| k.to_s }
      end

      # @return [Array<String>]
      def row_keys
        @record.row_keys
      end

      # @param io_in [IO]
      # @return [Array<Array<String>>]
      def parse(io_in, &block)
        record_lines = []
        collecting = false
        until io_in.eof do
          line = io_in.readline
          if line && is_known_line_type?(line)
            if is_record_header?(line)
              collecting = true
              process_record(record_lines, &block)
              record_lines = []
            end
            record_lines << line if collecting
          end
          break if io_in.eof
        end
        # catch trailing record after eof hit
        process_record(record_lines, &block)
      end

      # @param file_lines [String]
      # @return [Array<Array<String>>]
      def file_parse(file_lines)
        record_rows = []
        parse(StringIO.new(file_lines)) do |row|
          record_rows << row
        end
        record_rows
      end

      private def process_record(record_lines, &block)
        unless record_lines.empty?
          row = @record.parse(record_lines)
          block.call(row)
        end
      end

      # @param line [String]
      # @return [Bool]
      def is_known_line_type?(line)
        line_key = segment_peek(line)
        @segment_keys.include?(line_key)
      end

      # @param line [String]
      # @return [Bool]
      def is_record_header?(line)
        segment_peek(line) == @segment_keys.first
      end

      # @param record_file [String] really a whole file in a string? would expect something of IO
      # @return [Array<Hash{String => String}>]
      def parse_and_zip(record_file)
        record_rows = file_parse(record_file)
        zipped = []
        record_rows.each do |row|
          zipped << Hash[row_keys.zip(row)]
        end
        zipped
      end
    end
  end
end
