# frozen_string_literal: true

# Allow GitHub so feature specs with js: true can download geckodriver (webdrivers gem).
RSpec.configure do |config|
  config.before(:suite) do
    WebMock.disable_net_connect!(
      allow_localhost: true,
      allow: [
        'hyku-carrierwave-test.s3.amazonaws.com',
        'fcrepo',
        'solr',
        'chrome',
        'chromedriver.storage.googleapis.com',
        'github.com'
      ]
    )
  end
end
