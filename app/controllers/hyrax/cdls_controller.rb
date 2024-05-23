# frozen_string_literal: true
# Generated via
#  `rails generate hyrax:work Cdl`
module Hyrax
  # Generated controller for Cdl
  class CdlsController < ApplicationController
    # Adds Hyrax behaviors to the controller.
    include Hyrax::WorksControllerBehavior
    include Hyku::WorksControllerBehavior
    include Hyrax::BreadcrumbsForWorks
    self.curation_concern_type = ::CdlResource

    # Use a Valkyrie aware form service to generate Valkyrie::ChangeSet style
    # forms.
    self.work_form_service = Hyrax::FormFactory.new

    # Use this line if you want to use a custom presenter
    self.show_presenter = Hyrax::CdlPresenter
  end
end
