# frozen_string_literal: true
# rubocop:disable Metrics/BlockLength
namespace :hyku do
  desc "Delete orphaned Solr documents for works that no longer exist in the metadata store. " \
       "Usage: rake hyku:delete_orphaned_solr_docs[cname,id1 id2 id3]"
  task :delete_orphaned_solr_docs, [:cname, :work_ids] => :environment do |_t, args|
    cname = args[:cname]
    work_ids = args[:work_ids]&.split

    if cname.blank?
      abort "ERROR: cname argument is required.\n" \
            "Usage: rake hyku:delete_orphaned_solr_docs[cname,id1 id2 id3]"
    end

    if work_ids.blank?
      abort "ERROR: work_ids argument is required.\n" \
            "Usage: rake hyku:delete_orphaned_solr_docs[cname,id1 id2 id3]"
    end

    switch!(cname)

    work_ids.each do |id|
      Hyrax.query_service.find_by(id: id)
      Rails.logger.info("Work found - not deleting SolrDocument. ID: #{id}")
    rescue Valkyrie::Persistence::ObjectNotFoundError
      delete_solr_doc(uuid: id)
    end
  end

  def delete_solr_doc(uuid:)
    sd = SolrDocument.find(uuid)
    Hyrax.index_adapter.delete(resource: sd)
    Rails.logger.info("Deleted orphaned solr document for UUID: #{uuid}")
  rescue Blacklight::Exceptions::RecordNotFound
    Rails.logger.info("Orphaned solr document for ID: #{uuid} already deleted from Solr")
  end
end
