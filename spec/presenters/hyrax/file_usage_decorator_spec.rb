# frozen_string_literal: true

# HYRAX-BACKPORT: samvera/hyrax#7676
# Delete with the decorator this covers (Hyrax::FileUsageDecorator).
RSpec.describe Hyrax::FileUsageDecorator do
  let(:file_set) { valkyrie_create(:hyrax_file_set, depositor: 'someone@example.com', date_uploaded: 3.days.ago) }
  let(:usage) { Hyrax::FileUsage.new(file_set.id.to_s) }

  describe '#without_analytics' do
    it 'returns the presenter without querying analytics' do
      expect(FileViewStat).not_to receive(:statistics)
      expect(FileDownloadStat).not_to receive(:statistics)

      expect(usage.without_analytics).to equal(usage)
    end

    it 'zero-fills a row per day since the upload' do
      usage.without_analytics

      expect(usage.total_pageviews).to eq 0
      expect(usage.total_downloads).to eq 0
      expect(usage.to_flot.map { |series| series[:data].size }).to all(be >= 3)
    end
  end
end
