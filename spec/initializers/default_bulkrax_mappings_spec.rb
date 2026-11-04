# frozen_string_literal: true

RSpec.describe 'Default Bulkrax mappings' do
  it 'keeps descriptive fields in a standard export and drops system generated ones' do
    allow(Site).to receive(:account).and_return(nil)
    exporter = Bulkrax::Exporter.new(parser_klass: 'Bulkrax::CsvParser', generated_metadata: false,
                                     field_mapping: Bulkrax.field_mappings['Bulkrax::CsvParser'])
    exported = Bulkrax::CsvEntry.new(importerexporter: exporter).fetch_field_mapping.keys

    expect(exported).to include('abstract', 'additional_information', 'alternative_title', 'bibliographic_citation',
                                'rights_notes', 'rights_statement', 'source')
    expect(exported).not_to include('depositor', 'date_uploaded', 'admin_set_id')
  end
end
