# frozen_string_literal: true

# OVERRIDE Hyku v7.1.0 SplashController#index: load each public tenant's directory image and alt text for the PALS splash page.
#   Client-specific, keep.
module SplashControllerDecorator
  def index
    @accounts = Account.where('is_public = ?', true).order(cname: :asc)
    @images = []
    @alt_text = []
    @accounts.map do |account|
      Apartment::Tenant.switch(account.tenant) do
        @images << Site.instance&.directory_image&.url(:medium) || "https://via.placeholder.com/400?text=#{account.cname}"
        @alt_text << Site.instance&.directory_image_alt_text || account.cname
      end
    end
  end
end

SplashController.prepend(SplashControllerDecorator)
