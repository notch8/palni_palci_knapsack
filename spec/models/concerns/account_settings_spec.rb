# frozen_string_literal: true

RSpec.describe AccountSettings do
  let(:account) { FactoryBot.create(:account) }

  describe '#public_settings' do
    # Store the original environment value to restore it after the test
    around do |example|
      original_env = ENV['DISABLE_ANALYTICS_FEATURES']
      ENV['DISABLE_ANALYTICS_FEATURES'] = 'false'
      example.run
      ENV['DISABLE_ANALYTICS_FEATURES'] = original_env
    end

    context 'when is_superadmin is true' do
      let(:settings_list) do
        %i[allow_downloads
           allow_signup
           analytics
           analytics_reporting
           batch_email_notifications
           bulkrax_field_mappings
           cache_api
           contact_email
           contact_email_to
           depositor_email_notifications
           doi_reader
           doi_writer
           email_domain
           email_format
           email_subject_prefix
           file_acl
           file_size_limit
           geonames_username
           google_analytics_id
           google_analytics_property_id
           gtm_id
           oai_admin_email
           oai_prefix
           oai_sample_identifier
           s3_bucket
           smtp_settings
           solr_collection_options
           ssl_configured].sort
      end

      it 'returns all settings except private and disabled settings' do
        expect(account.public_settings(is_superadmin: true).keys.sort).to eq settings_list
        expect(account.public_settings(is_superadmin: true).size).to eq settings_list.size
      end
    end

    context 'when is_superadmin is false' do
      let(:settings_list) do
        %i[allow_downloads
           allow_signup
           analytics_reporting
           cache_api
           contact_email_to
           doi_reader
           doi_writer
           email_domain
           email_format
           email_subject_prefix
           geonames_username
           google_analytics_id
           google_analytics_property_id
           gtm_id
           oai_admin_email
           smtp_settings
           solr_collection_options
           ssl_configured].sort
      end

      it 'returns all settings except private, disabled, and superadmin settings' do
        # Removes superadmin-only settings (analytics_provider, file_acl, file_size_limit,
        # oai_prefix, oai_sample_identifier, s3_bucket) and disabled settings
        expect(account.public_settings(is_superadmin: false).keys.sort).to eq settings_list
        expect(account.public_settings(is_superadmin: false).size).to eq settings_list.size
      end
    end
  end
end
