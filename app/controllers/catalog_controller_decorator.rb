# frozen_string_literal: true

module CatalogControllerDecorator
  extend ActiveSupport::Concern

  prepended do
    before_action :sort_alphabetical
  end

  def sort_alphabetical
    params[:sort] = 'title_ssi asc' if params[:f].present?
  end
end

CatalogController.prepend(CatalogControllerDecorator)

def solr_name(*args)
  ActiveFedora.index_field_mapper.solr_name(*args)
end

def self.uploaded_field
  'system_create_dtsi'
end

# rubocop:disable Metrics/BlockLength
CatalogController.configure_blacklight do |config|
  # We need need to clear the facet fields that are already declared in the
  # catalog controller; if we do not, we'll encounter exceptions regarding
  # duplicate declarations.
  config.facet_fields.clear

  config.add_facet_field 'human_readable_type_sim', label: "Type", limit: 5
  config.add_facet_field 'resource_type_sim', label: "Resource Type", limit: 5
  config.add_facet_field 'creator_sim', limit: 5
  config.add_facet_field 'contributor_sim', label: "Contributor", limit: 5
  config.add_facet_field 'keyword_sim', limit: 5
  config.add_facet_field 'subject_sim', limit: 5
  config.add_facet_field 'language_sim', limit: 5
  config.add_facet_field 'based_near_label_sim', limit: 5
  config.add_facet_field 'publisher_sim', limit: 5
  config.add_facet_field 'file_format_sim', limit: 5
  config.add_facet_field 'contributing_library_sim', limit: 5
  config.add_facet_field 'date_ssi', label: 'Date Created', range: { num_segments: 10, assumed_boundaries: [1100, Time.zone.now.year + 2], segments: false, slider_js: false, maxlength: 4 }
  config.add_facet_field 'member_of_collections_ssim', limit: 5, label: 'Collections'
  config.add_facet_field 'account_institution_name_ssim', label: 'Institution', limit: 5

  # keep iiif_print index fields from Hyku so we don't have to redefine snippets logic
  config.index_fields.keys.each do |key|
    next if key == 'all_text_timv'
    next if key == 'all_text_tsimv'

    config.index_fields.delete(key)
  end
  config.add_index_field 'based_near_label_tesim', itemprop: 'contentLocation', link_to_facet: 'based_near_label_sim'
  config.add_index_field solr_name("title", :stored_searchable), label: "Title", itemprop: 'name', if: false
  config.add_index_field solr_name("creator", :stored_searchable), itemprop: 'creator', link_to_search: solr_name("creator", :facetable)
  config.add_index_field solr_name("date", :stored_searchable), itemprop: 'date'
  config.add_index_field solr_name('collection_subtitle', :stored_searchable), label: "Collection Subtitle"
  config.add_index_field solr_name("description", :stored_searchable), itemprop: 'description', helper_method: :truncate_and_iconify_auto_link
  config.add_index_field solr_name("resource_type", :stored_searchable), label: "Resource Type", link_to_search: solr_name("resource_type", :facetable)
  config.add_index_field solr_name('learning_resource_type', :stored_searchable), label: "Learning resource type"
  config.add_index_field solr_name('education_level', :stored_searchable), label: "Education level"
  config.add_index_field solr_name('audience', :stored_searchable), label: "Audience"
  config.add_index_field solr_name('discipline', :stored_searchable), label: "Discipline"

  config.show_fields.clear

  config.add_show_field solr_name("abstract", :stored_searchable), label: 'Abstract'
  config.add_show_field solr_name('admin_note', :stored_searchable), label: "Administrative Notes"
  config.add_show_field solr_name("alternative_title", :stored_searchable), label: "Alternative title"
  config.add_show_field solr_name("creator", :stored_searchable)
  config.add_show_field solr_name("contributor", :stored_searchable)
  config.add_show_field solr_name("related_url", :stored_searchable), helper_method: :truncate_and_iconify_auto_link
  config.add_show_field solr_name('learning_resource_type', :stored_searchable)
  config.add_show_field solr_name('education_level', :stored_searchable)
  config.add_show_field solr_name('audience', :stored_searchable)
  config.add_show_field solr_name('discipline', :stored_searchable)
  config.add_show_field solr_name("date", :stored_searchable), label: "Date", helper_method: :human_readable_date
  config.add_show_field solr_name("description", :stored_searchable), helper_method: :truncate_and_iconify_auto_link
  config.add_show_field solr_name("table_of_contents", :stored_searchable), label: "Table of contents"
  config.add_show_field solr_name("subject", :stored_searchable)
  config.add_show_field solr_name("rights_statement", :stored_searchable), helper_method: :rights_statement_links
  config.add_show_field solr_name("license", :stored_searchable), helper_method: :license_links
  config.add_show_field solr_name("rights_holder", :stored_searchable), label: "Rights holder"
  config.add_show_field solr_name("additional_information", :stored_searchable), label: "Additional information"
  config.add_show_field solr_name("language", :stored_searchable)
  config.add_show_field solr_name("oer_size", :stored_searchable), label: "Size"
  config.add_show_field solr_name("publisher", :stored_searchable)
  config.add_show_field solr_name("identifier", :stored_searchable)
  config.add_show_field solr_name("resource_type", :stored_searchable), label: "Resource Type"
  config.add_show_field solr_name('accessibility_feature', :stored_searchable)
  config.add_show_field solr_name('accessibility_hazard', :stored_searchable)
  config.add_show_field solr_name('accessibility_summary', :stored_searchable), label: "Accessibility summary"
  config.add_show_field solr_name("keyword", :stored_searchable)
  config.add_show_field solr_name("based_near_label", :stored_searchable)
  config.add_show_field solr_name("date_uploaded", :stored_searchable)
  config.add_show_field solr_name("date_modified", :stored_searchable)
  config.add_show_field solr_name("date_created", :stored_searchable)
  config.add_show_field solr_name("format", :stored_searchable)
  config.add_show_field solr_name('extent', :stored_searchable)
  config.add_show_field solr_name('previous_version_id', :stored_searchable)
  config.add_show_field solr_name('newer_version_id', :stored_searchable)
  config.add_show_field solr_name('related_item_id', :stored_searchable)
  config.add_show_field solr_name('contributing_library', :stored_searchable)
  config.add_show_field solr_name('library_catalog_identifier', :stored_searchable)
  config.add_show_field solr_name('chronology_note', :stored_searchable)

  # list of all the search_fields that will use the default configuration below.
  search_fields_without_customization = [
    { name: 'title', label: 'Title' },
    { name: 'creator', label: 'Creator' },
    { name: 'date_created', label: 'Date or Date Created' },
    { name: 'keyword', label: 'Keyword' },
    { name: 'license', label: 'License' },
    { name: 'subject', label: 'Subject' },
    { name: 'abstract', label: 'Abstract' },
    { name: 'advisor', label: 'Advisor' },
    { name: 'accessibility_feature', label: 'Accessibility Feature' },
    { name: 'accessibility_hazard', label: 'Accessibility Hazard' },
    { name: 'accessibility_summary', label: 'Accessibility Summary' },
    { name: 'additional_information', label: 'Additional Rights Information or Access Rights' },
    { name: 'alternative_title', label: 'Alternative Title' },
    { name: 'audience', label: 'Audience' },
    { name: 'bibliographic_citation', label: 'Bibliographic Citation' },
    { name: 'committee_member', label: 'Committee Member' },
    { name: 'contributor', label: 'Contributor' },
    { name: 'department', label: 'Department' },
    { name: 'depositor', label: 'Depositor' },
    { name: 'description', label: 'Description' },
    { name: 'degree_discipline', label: 'Discipline' },
    { name: 'education_level', label: 'Education Level' },
    { name: 'extent', label: 'Extent' },
    { name: 'degree_grantor', label: 'Grantor' },
    { name: 'identifier', label: 'Identifier' },
    { name: 'language', label: 'Language' },
    { name: 'learning_resource_type', label: 'Learning Resource Type' },
    { name: 'degree_level', label: 'Level' },
    { name: 'publisher', label: 'Publisher' },
    { name: 'related_url', label: 'Related URL' },
    { name: 'rights_holder', label: 'Rights Holder' },
    { name: 'rights_notes', label: 'Rights Notes' },
    { name: 'rights_statement', label: 'Rights or Rights Statement' },
    { name: 'size', label: 'Size' },
    { name: 'source', label: 'Source' },
    { name: 'table_of_contents', label: 'Table of Contents' },
    { name: 'resource_type', label: 'Type or Resource Type' }
  ]

  search_fields_without_customization.each do |search_field|
    config.search_fields.delete(search_field[:name])
    config.add_search_field(search_field[:name]) do |field|
      field.label = search_field[:label]
      field.solr_parameters = { "spellcheck.dictionary": search_field[:name] }
      solr_name = "#{search_field[:name]}_tesim"
      field.solr_local_parameters = {
        qf: solr_name,
        pf: solr_name
      }
    end
  end

  config.search_fields['all_fields'].clear
  config.add_search_field('all_fields', label: 'All Fields', include_in_advanced_search: false) do |field|
    title_name = 'title_tesim'
    all_show_names = config.show_fields.values.map(&:field)
    all_show_names |= [title_name]
    field.solr_parameters = {
      qf: "#{all_show_names.join(' ')} file_format_tesim all_text_timv all_text_tsimv",
      pf: title_name.to_s
    }
  end

  # If there is something additional about a search field that needs to be customized i.e. whether to include in advanced search, or if it needs a different solr name, add it below
  config.search_fields.delete('date')
  config.add_search_field('date') do |field|
    solr_name = 'date_ssi'
    field.include_in_advanced_search = false
    field.solr_local_parameters = {
      qf: solr_name,
      pf: solr_name
    }
  end

  config.search_fields.delete('based_near_label')
  config.add_search_field('based_near_label') do |field|
    solr_name = 'based_near_label_tesim'
    field.include_in_advanced_search = false
    field.label = 'Location'
    field.solr_local_parameters = {
      qf: solr_name,
      pf: solr_name
    }
  end

  # format cannot be included in advanced search because an error is thrown in Blacklight when formats do not match specific mime types
  # see https://github.com/projectblacklight/blacklight/blob/13a8122fc6495e52acabc33875b80b51613d8351/app/controllers/concerns/blacklight/catalog.rb#L167
  # and the error on https://github.com/projectblacklight/blacklight/blob/13a8122fc6495e52acabc33875b80b51613d8351/app/controllers/concerns/blacklight/catalog.rb#L206
  config.search_fields.delete('format')
  config.add_search_field('format') do |field|
    field.include_in_advanced_search = false
    field.solr_parameters = {
      "spellcheck.dictionary": "format"
    }
    solr_name = 'format_tesim'
    field.solr_local_parameters = {
      qf: solr_name,
      pf: solr_name
    }
  end

  # "sort results by" select (pulldown)
  # label in pulldown is followed by the name of the SOLR field to sort by and
  # whether the sort is ascending or descending (it must be asc or desc
  # except in the relevancy case).
  # label is key, solr field is value
  config.sort_fields.clear

  config.add_sort_field "score desc, #{uploaded_field} desc", label: "relevance"
  config.add_sort_field "title_ssi asc", label: "title (A-Z)"
  config.add_sort_field "title_ssi desc", label: "title (Z-A)"
  config.add_sort_field "date_ssi desc", label: "date created \u25BC"
  config.add_sort_field "date_ssi asc", label: "date created \u25B2"
  config.add_sort_field "#{uploaded_field} desc", label: "date uploaded \u25BC"
  config.add_sort_field "#{uploaded_field} asc", label: "date uploaded \u25B2"
end
