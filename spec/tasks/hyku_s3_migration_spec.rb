# frozen_string_literal: true

require 'rails_helper'
require 'rake'

RSpec.describe 'hyku:s3_migration tasks' do
  before do
    Rake::Task.define_task(:environment) unless Rake::Task.task_defined?(:environment)
    Rake.application.rake_require 'tasks/s3_migration' unless Rake::Task.task_defined?('s3_migration:report')
    Rake.application.rake_require 'tasks/hyku_s3_migration' unless Rake::Task.task_defined?('hyku:s3_migration:report')
  end

  %w[migrate verify report quarantine rollback purge].each do |step|
    it "refuses to run s3_migration:#{step} outside a tenant" do
      allow(S3Migration::Tasks).to receive(:run)
      Rake::Task["s3_migration:#{step}"].reenable
      Rake::Task['hyku:s3_migration:refuse_untenanted'].reenable

      expect { Rake::Task["s3_migration:#{step}"].invoke }
        .to raise_error(SystemExit).and output(/Run these per tenant/).to_stderr
      expect(S3Migration::Tasks).not_to have_received(:run)
    end
  end

  it 'runs the gem task in the tenant for hyku:s3_migration:report' do
    account = instance_double(Account, cname: 'a.example.com')
    allow(Hyku::EachTenant).to receive(:call).and_yield(account).and_return([])
    allow(S3Migration::Tasks).to receive(:run)
    Rake::Task['hyku:s3_migration:report'].reenable

    expect { Rake::Task['hyku:s3_migration:report'].invoke }.to output(/Tenant: a.example.com/).to_stdout
    expect(S3Migration::Tasks).to have_received(:run).with('report')
  end
end
