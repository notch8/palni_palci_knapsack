# frozen_string_literal: true

## Set custom bulkrax parser field mappings for app
parser_mappings = {
  'abstract' => { from: ['abstract'], split: '\|', generated: true },
  'accessibility_feature' => { from: ['accessibility_feature'], split: '\|' },
  'accessibility_hazard' => { from: ['accessibility_hazard'], split: '\|' },
  'accessibility_summary' => { from: ['accessibility_summary'] },
  'additional_information' => { from: ['additional_information'], split: '\|', generated: true },
  'admin_note' => { from: ['admin_note'] },
  'admin_set_id' => { from: ['admin_set_id'], generated: true },
  'alternate_version' => { from: ['alternate_version'], split: '\|' },
  'alternative_title' => { from: ['alternative_title'], split: '\|', generated: true },
  'arkivo_checksum' => { from: ['arkivo_checksum'], split: '\|', generated: true },
  'audience' => { from: ['audience'], split: '\|' },
  'based_near' => { from: ['location'], split: '\|' },
  'bibliographic_citation' => { from: ['bibliographic_citation'], split: '\|', generated: true },
  'bulkrax_identifier' => { from: ['source_identifier'], source_identifier: true, generated: true, search_field: 'bulkrax_identifier_tesim' },
  'children' => { from: ['children'], split: /\s*[;|]\s*/, related_children_field_mapping: true },
  'chronology_note' => { from: ['chronology_note'], split: '\|' },
  'committee_member' => { from: ['committee_member'], split: '\|' },
  'contributing_library' => { from: ['contributing_library'], split: '\|' },
  'contributor' => { from: ['contributor'], split: '\|' },
  'creator' => { from: ['author', 'creator'], split: '\|' },
  'date_created' => { from: ['date', 'date_created'], split: '\|' },
  'date_uploaded' => { from: ['date_uploaded'], generated: true },
  'date' => { from: ['date'], split: '\|' },
  'degree_discipline' => { from: ['discipline'], split: '\|' },
  'degree_grantor' => { from: ['grantor'], split: '\|' },
  'degree_level' => { from: ['level'], split: '\|' },
  'degree_name' => { from: ['degree'], split: '\|' },
  'depositor' => { from: ['depositor'], split: '\|', generated: true },
  'description' => { from: ['description'], split: '\|' },
  'discipline' => { from: ['discipline'], split: '\|' },
  'education_level' => { from: ['education_level'], split: '\|' },
  'embargo_id' => { from: ['embargo_id'], generated: true },
  'file' => { from: ['item'], split: '\|' },
  'identifier' => { from: ['identifier'], split: '\|' },
  'import_url' => { from: ['import_url'], split: '\|', generated: true },
  'keyword' => { from: ['keyword'], split: '\|' },
  'label' => { from: ['label'], generated: true },
  'language' => { from: ['language'], split: '\|' },
  'learning_resource_type' => { from: ['learning_resource_type'], split: '\|' },
  'lease_id' => { from: ['lease_id'], generated: true },
  'library_catalog_identifier' => { from: ['library_catalog_identifier'], split: '\|' },
  'license' => { from: ['license'], split: '\|' },
  'newer_version' => { from: ['newer_version'], split: '\|' },
  'oer_size' => { from: ['oer_size'], split: '\|' },
  'on_behalf_of' => { from: ['on_behalf_of'], generated: true },
  'owner' => { from: ['owner'], generated: true },
  'parents' => { from: ['parents'], split: /\s*[;|]\s*/, related_parents_field_mapping: true },
  'previous_version' => { from: ['previous_version'], split: '\|' },
  'proxy_depositor' => { from: ['proxy_depositor'], generated: true },
  'publisher' => { from: ['publisher'], split: '\|' },
  'path' => { from: ['redirect_path'], object: 'redirects', nested_attributes: true },
  'is_display_url' => { from: ['redirect_is_display_url'], object: 'redirects', nested_attributes: true },
  'related_item' => { from: ['related_item'], split: '\|' },
  'related_url' => { from: ['related_url', 'relation'], split: '\|' },
  'relative_path' => { from: ['relative_path'], split: '\|', generated: true },
  'rendering_ids' => { from: ['rendering_ids'], split: '\|', generated: true },
  'representative_id' => { from: ['representative_id'], generated: true },
  'resource_type' => { from: ['type'], split: '\|' },
  'rights_holder' => { from: ['rights_holder'], split: '\|' },
  'rights_notes' => { from: ['rights_notes'], split: '\|', generated: true },
  'rights_statement' => { from: ['rights', 'rights_statement'], split: '\|', generated: true },
  'source' => { from: ['source'], split: '\|', generated: true },
  'state' => { from: ['state'], generated: true },
  'subject' => { from: ['subject'], split: '\|' },
  'table_of_contents' => { from: ['table_of_contents'], split: '\|' },
  'title' => { from: ['title'], split: '\|' },
  'video_embed' => { from: ['video_embed'] }
}

# currently Bulkrax does not support headers with spaces
# here we add the key but with the underscore turned into a space to accommodate
parser_mappings.each do |key, value|
  value[:from] += ([key.tr('_', ' ')] + value[:from].map { |f| f.tr('_', ' ') })
  value[:from].uniq!
end

# all parsers use the same mappings:
mappings = {}
mappings["Bulkrax::BagitParser"] = parser_mappings
mappings["Bulkrax::CsvParser"] = parser_mappings
Hyku.default_bulkrax_field_mappings = mappings
