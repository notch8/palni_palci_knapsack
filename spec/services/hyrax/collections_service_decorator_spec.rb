# frozen_string_literal: true

RSpec.describe Hyrax::CollectionsServiceDecorator do
  subject(:service) { Hyrax::CollectionsService.new(context) }

  let(:config) { Hyrax::My::WorksController.blacklight_config }
  let(:context) do
    double(blacklight_config: config,
           repository: config.repository,
           current_ability: instance_double(Ability),
           params: ActionController::Parameters.new(f: { resource_type_sim: ['Article'] }, q: 'thesis', page: '2'))
  end

  it 'builds the collection query without the page search params' do
    expect(service.send(:user_params)).to be_empty
    expect(service.send(:search_state).params).to be_empty
  end
end
