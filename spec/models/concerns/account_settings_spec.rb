# frozen_string_literal: true

RSpec.describe AccountSettings do
  let(:account) { FactoryBot.create(:account) }

  describe '#public_settings' do
    context 'when is_superadmin is true' do
      let(:settings_list) do
        %i[allow_downloads
           allow_signup
           analytics_provider
           cache_api
           contact_email
           contact_email_to
           doi_reader
           doi_writer
           email_domain
           email_format
           email_subject_prefix
           file_acl
           file_size_limit
           geonames_username
           google_analytics_id
           gtm_id
           oai_admin_email
           oai_prefix
           oai_sample_identifier
           s3_bucket
           smtp_settings
           solr_collection_options
           ssl_configured]
      end

      it 'returns all settings except private and disabled settings' do
        expect(account.public_settings(is_superadmin: true).keys.sort).to eq settings_list
        expect(account.public_settings(is_superadmin: true).size).to eq 23
      end
    end

    context 'when is_superadmin is false' do
      let(:settings_list) do
        %i[allow_downloads
           allow_signup
           cache_api
           contact_email_to
           doi_reader
           doi_writer
           email_domain
           email_format
           email_subject_prefix
           geonames_username
           google_analytics_id
           gtm_id
           oai_admin_email
           smtp_settings
           solr_collection_options
           ssl_configured]
      end

      it 'returns all settings except private, disabled, and superadmin settings' do
        expect(Account.superadmin_settings.size).to eq 7
        expect(account.public_settings(is_superadmin: false).keys.sort).to eq settings_list
        expect(account.public_settings(is_superadmin: false).size).to eq 16
      end
    end
  end
end
