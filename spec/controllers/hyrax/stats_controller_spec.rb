# frozen_string_literal: true

# HYRAX-BACKPORT: samvera/hyrax#7676
# Delete with the decorator this covers (Hyrax::StatsControllerDecorator).
RSpec.describe Hyrax::StatsController, type: :controller do
  let(:user) { create(:user) }
  let(:google_message) { 'Property 123456 is not shared with service-account@example.iam.gserviceaccount.com' }
  let(:unavailable) { I18n.t('hyrax.stats.analytics_unavailable') }
  let(:setup_messages) { %w[permission general].map { |type| CGI.escapeHTML(I18n.t("hyrax.admin.analytics.errors.#{type}.message")) } }

  routes { Hyrax::Engine.routes }
  render_views

  before do
    sign_in viewer if viewer
    request.env['HTTP_REFERER'] = 'http://test.host/foo'
  end

  shared_examples 'a stats page with a plain analytics notice' do
    {
      'permission' => Google::Cloud::PermissionDeniedError,
      'general' => Google::Cloud::InvalidArgumentError
    }.each do |type, error_class|
      context "with a #{type} error" do
        let(:error) { error_class.new(google_message) }

        it 'renders the page with only a one-line notice' do
          get action, params: { id: }

          expect(response).to be_successful
          expect(response).to render_template("stats/#{action}")
          expect(assigns(:analytics_error)).to be_nil
          expect(response.body).to include(unavailable)
          setup_messages.each { |message| expect(response.body).not_to include(message) }
          expect(response.body).not_to include('service-account@example')
          expect(response.body).not_to include('Technical Details')
        end
      end
    end
  end

  shared_examples 'a stats page with the setup notice' do
    {
      'permission' => Google::Cloud::PermissionDeniedError,
      'general' => Google::Cloud::InvalidArgumentError
    }.each do |type, error_class|
      context "with a #{type} error" do
        let(:error) { error_class.new(google_message) }

        it 'renders the page with the matching setup notice and hides the Google message' do
          get action, params: { id: }

          expect(response).to be_successful
          expect(assigns(:analytics_error)).to be_present
          expect(response.body).to include(CGI.escapeHTML(I18n.t("hyrax.admin.analytics.errors.#{type}.message")))
          expect(response.body).not_to include(unavailable)
          expect(response.body).not_to include('service-account@example')
          expect(response.body).not_to include('Technical Details')
        end
      end
    end
  end

  shared_examples 'a stats page that survives Google errors' do
    context 'as a regular user' do
      let(:viewer) { user }

      it_behaves_like 'a stats page with a plain analytics notice'
    end

    context 'as an anonymous visitor' do
      let(:viewer) { nil }

      it_behaves_like 'a stats page with a plain analytics notice'
    end

    context 'as an admin' do
      let(:viewer) { create(:user, roles: [:admin]) }

      it_behaves_like 'a stats page with the setup notice'
    end

    context 'as a superadmin' do
      let(:viewer) { create(:superadmin) }

      it_behaves_like 'a stats page with the setup notice'
    end
  end

  describe '#file' do
    let(:action) { :file }
    let(:file_set) { valkyrie_create(:hyrax_file_set, depositor: user.user_key, read_groups: ['public'], date_uploaded: 3.days.ago) }
    let(:id) { file_set.id.to_s }

    before { allow(Hyrax::Analytics).to receive(:page_statistics).and_raise(error) }

    it_behaves_like 'a stats page that survives Google errors'

    context 'as a regular user with a permission error' do
      let(:viewer) { user }
      let(:error) { Google::Cloud::PermissionDeniedError.new(google_message) }

      it 'shows zeroed totals' do
        get :file, params: { id: }

        expect(assigns(:stats).total_pageviews).to eq 0
        expect(assigns(:stats).total_downloads).to eq 0
      end
    end
  end

  describe '#work' do
    let(:action) { :work }
    let(:work) { valkyrie_create(:generic_work_resource, depositor: user.user_key, read_groups: ['public']) }
    let(:id) { work.id.to_s }

    before { allow(Hyrax::Analytics).to receive(:daily_events_for_id).and_raise(error) }

    it_behaves_like 'a stats page that survives Google errors'

    context 'as a regular user with a permission error' do
      let(:viewer) { user }
      let(:error) { Google::Cloud::PermissionDeniedError.new(google_message) }

      it 'shows zeroed totals' do
        get :work, params: { id: }

        expect(assigns(:pageviews).all).to eq 0
        expect(assigns(:downloads).all).to eq 0
      end
    end
  end
end
