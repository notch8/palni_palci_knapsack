# frozen_string_literal: true

# HYRAX-BACKPORT: samvera/hyrax#7676
# Delete with the decorator this covers (Hyrax::StatsControllerDecorator).
RSpec.describe Hyrax::StatsController, type: :controller do
  let(:user) { create(:user) }
  let(:google_message) { 'Property 123456 is not shared with service-account@example.iam.gserviceaccount.com' }

  routes { Hyrax::Engine.routes }
  render_views

  before do
    sign_in user
    request.env['HTTP_REFERER'] = 'http://test.host/foo'
  end

  shared_examples 'a stats page that survives Google errors' do
    {
      'permission' => Google::Cloud::PermissionDeniedError,
      'general' => Google::Cloud::InvalidArgumentError
    }.each do |type, error_class|
      context "with a #{type} error" do
        let(:error) { error_class.new(google_message) }

        it 'renders the page with the matching notice and hides the Google message' do
          get action, params: { id: id }

          expect(response).to be_successful
          expect(response).to render_template("stats/#{action}")
          expect(assigns(:analytics_error)).to be_present
          expect(response.body).to include(CGI.escapeHTML(I18n.t("hyrax.admin.analytics.errors.#{type}.message")))
          expect(response.body).not_to include('service-account@example')
          expect(response.body).not_to include('Technical Details')
        end
      end
    end
  end

  describe '#file' do
    let(:action) { :file }
    let(:file_set) { valkyrie_create(:hyrax_file_set, depositor: user.user_key, edit_users: [user.user_key], date_uploaded: 3.days.ago) }
    let(:id) { file_set.id.to_s }

    before { allow(Hyrax::Analytics).to receive(:page_statistics).and_raise(error) }

    it_behaves_like 'a stats page that survives Google errors'

    context 'with a permission error' do
      let(:error) { Google::Cloud::PermissionDeniedError.new(google_message) }

      it 'shows zeroed totals' do
        get :file, params: { id: id }

        expect(assigns(:stats).total_pageviews).to eq 0
        expect(assigns(:stats).total_downloads).to eq 0
      end
    end
  end

  describe '#work' do
    let(:action) { :work }
    let(:work) { valkyrie_create(:generic_work_resource, depositor: user.user_key, edit_users: [user.user_key]) }
    let(:id) { work.id.to_s }

    before { allow(Hyrax::Analytics).to receive(:daily_events_for_id).and_raise(error) }

    it_behaves_like 'a stats page that survives Google errors'

    context 'with a permission error' do
      let(:error) { Google::Cloud::PermissionDeniedError.new(google_message) }

      it 'shows zeroed totals' do
        get :work, params: { id: id }

        expect(assigns(:pageviews).all).to eq 0
        expect(assigns(:downloads).all).to eq 0
      end
    end
  end
end
