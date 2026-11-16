# frozen_string_literal: true

# OVERRIDE Hyku v7.1.0 AppIndexer#generate_solr_document: index admin_note on ActiveFedora works.
#   No longer used; remove in a follow-up to #820.
module AppIndexerDecorator
  def generate_solr_document
    super.tap do |solr_doc|
      solr_doc['admin_note_tesim'] = object.admin_note if object.respond_to?(:admin_note)
    end
  end
end

AppIndexer.prepend(AppIndexerDecorator)
