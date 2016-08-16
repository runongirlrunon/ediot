require 'spec_helper'
require 'csv'

RSpec.describe Grnds::Ediot::Parser do

  context 'given a simple example' do
    let(:raw_records){
      %Q{ISA*00**00
      QTY*TO*3
      INS*Y*18
      REF*23*BOB SMITH
      INS*Y*19
      REF*23*SALLY SUE
      }
    }

    let(:definition) {{
      INS: { size: 3 },
      REF: { size: 3 }
    }}

    let(:parser) { Grnds::Ediot::Parser.new(definition) }

    describe '#is_known_line_type?' do
      it 'is true when line type is defined' do
        expect(parser.is_known_line_type?('INS*0*9')).to be true
        expect(parser.is_known_line_type?('REF*1*8')).to be true
      end

      it 'is false when the line type is not defined' do
        expect(parser.is_known_line_type?('FOO*1*8')).to be false
      end
    end

    describe '#is_record_header?' do
      it 'is true when the line is a header record' do
        expect(parser.is_record_header?('INS*0*9')).to be true
      end

      it 'is false when the line is not a header record' do
        expect(parser.is_record_header?('REF*1*8')).to be false
      end
    end

    describe 'record parsing' do
      let(:records) { parser.file_parse(raw_records) }

      it 'processes two records' do
        expect(records.count).to eql(2)
      end
    end
  end

  context 'given a single record in a file' do
    let(:raw_records) { File.open('spec/support/simple_sample.txt','r').read }
    let(:processed_result) { CSV.read('spec/support/processed_simple_sample.csv', headers: true) }
    let(:parser) { Grnds::Ediot::Parser.new }

    it 'proceses the records correctly' do
      zipped = parser.parse_and_zip(raw_records)
      processed_result.each_with_index do |csv_row, idx|
        zipped[idx].each do |row_key, row_val|
          expect(csv_row[row_key]).to eql(row_val), "Expected parsed value '#{row_val}' to equal '#{csv_row[row_key]}' from column '#{row_key}' and row #{idx} in the csv file"
        end
      end
    end
  end

  describe 'Stream processing IO files' do

    context 'given input file object' do

      let(:processed_result) { CSV.read('spec/support/processed_simple_sample.csv', headers: true) }
      let(:input_file_path) { 'spec/support/simple_sample.txt' }
      let(:in_file) { File.open(input_file_path, 'r') }
      let(:out_file) { StringIO.new }
      let(:parser) { Grnds::Ediot::Parser.new }

      it 'processes the records in the file' do
        column_headers = parser.row_keys
        out_file << CSV::Row.new(column_headers,column_headers, true).to_s
        parser.parse(in_file) do |row|
          out_file << CSV::Row.new(column_headers,row).to_s
        end
        streamed_csv = CSV.parse(out_file.string, headers: true)
        processed_result.each_with_index do |csv_row, idx|
          streamed_csv[idx].each do |row_key, row_val|
            expect(csv_row[row_key]).to eql(row_val), "Expected parsed value '#{row_val}' to equal '#{csv_row[row_key]}' from column '#{row_key}' and row #{idx} in the csv file"
          end
        end
      end

    end

    after(:each) do |example|
      if example.exception && out_file
        line = example.metadata[:line_number]
        file_name = File.basename(example.metadata[:file_path], ".rb")
        fail_file = "tmp/#{file_name}_failure_#{line}.txt"
        puts "Failure! Wrote output to file '#{fail_file}'"
        File.open(fail_file,'w') { |f| f << out_file.string }
      end
    end

  end
end
