# frozen_string_literal: true

# HYRAX-BACKPORT: samvera/hyrax#7676
# Delete with the decorator this covers (Hyrax::StatsControllerDecorator).

RSpec.describe Hyrax::StatsController, type: :controller do
  let(:user) { create(:user) }
  let(:error) { Google::Cloud::PermissionDeniedError.new('User does not have sufficient permissions for this property.') }

  routes { Hyrax::Engine.routes }
  render_views

  before do
    allow_any_instance_of(User).to receive(:groups).and_return([])
    sign_in user
    request.env['HTTP_REFERER'] = 'http://test.host/foo'
  end

  describe '#file' do
    let(:file_set) { valkyrie_create(:hyrax_file_set, depositor: user.user_key, edit_users: [user.user_key], date_uploaded: 3.days.ago) }

    before { allow(Hyrax::Analytics).to receive(:page_statistics).and_raise(error) }

    it 'renders zeroed data and an analytics notice' do
      get :file, params: { id: file_set.id.to_s }
      expect(response).to be_successful
      expect(response).to render_template('stats/file')
      expect(assigns(:analytics_error)).to be_present
      expect(response.body).to include(I18n.t('hyrax.admin.analytics.errors.permission.message'))
      expect(assigns(:stats).total_pageviews).to eq 0
      expect(assigns(:stats).total_downloads).to eq 0
    end
  end

  describe '#work' do
    let(:work) { valkyrie_create(:generic_work_resource, depositor: user.user_key, edit_users: [user.user_key]) }

    before { allow(Hyrax::Analytics).to receive(:daily_events_for_id).and_raise(error) }

    it 'renders zeroed data and an analytics notice' do
      get :work, params: { id: work.id.to_s }
      expect(response).to be_successful
      expect(response).to render_template('stats/work')
      expect(assigns(:analytics_error)).to be_present
      expect(response.body).to include(I18n.t('hyrax.admin.analytics.errors.permission.message'))
      expect(assigns(:pageviews).all).to eq 0
      expect(assigns(:downloads).all).to eq 0
    end

    context 'with a non-permission Google error' do
      let(:error) { Google::Cloud::InvalidArgumentError.new('Invalid property') }

      it 'renders the general notice' do
        get :work, params: { id: work.id.to_s }
        expect(response).to be_successful
        expect(response.body).to include(CGI.escapeHTML(I18n.t('hyrax.admin.analytics.errors.general.message')))
      end
    end
  end
end
