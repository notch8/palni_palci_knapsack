# frozen_string_literal: true

require 'rails_helper'
require 'rake'

RSpec.describe 'hyku_knapsack:m3_profile_for_tenant' do
  let(:task_name) { 'hyku_knapsack:m3_profile_for_tenant' }

  before do
    Rake.application.rake_require 'tasks/m3_profile_update' unless Rake::Task.task_defined?(task_name)
    Rake::Task.define_task(:environment) unless Rake::Task.task_defined?(:environment)
  end

  def invoke_task(*args)
    Rake::Task[task_name].reenable
    Rake::Task[task_name].invoke(*args)
  end

  # The rake task delegates to M3ProfileTaskRunner, which calls the service.
  # We stub the service entirely so these specs focus only on the
  # task/runner contract: argument parsing, tenant iteration, emoji
  # selection, summary formatting, and report-file writing. Service
  # internals are covered separately in
  # spec/services/hyku_knapsack/m3_profile_updater_spec.rb.

  let(:updater) { instance_double(HykuKnapsack::M3ProfileUpdater) }

  before do
    allow(HykuKnapsack::M3ProfileUpdater).to receive(:new).and_return(updater)
    allow(updater).to receive(:call)
  end

  describe 'argument validation' do
    it 'raises if name is missing' do
      expect { invoke_task }.to raise_error(ArgumentError, /Missing required argument: name/)
    end

    it 'raises if action is missing' do
      expect { invoke_task('example') }.to raise_error(ArgumentError, /Missing required argument: action/)
    end

    it 'raises if revision is missing' do
      expect { invoke_task('example', 'audit') }.to raise_error(ArgumentError, /Missing required argument: revision/)
    end

    it 'raises if action is not audit or apply' do
      expect { invoke_task('example', 'bogus', 'update') }
        .to raise_error(ArgumentError, /Unknown action/)
    end

    it 'raises if revision is not update or add' do
      expect { invoke_task('example', 'audit', 'bogus') }
        .to raise_error(ArgumentError, /Unknown revision/)
    end
  end

  describe 'single-tenant invocation' do
    let(:account) { instance_double(Account, name: 'example', cname: 'example.test') }
    let(:report) { build_report(status: :no_changes) }

    before do
      allow(Account).to receive(:find_by).with(name: 'example').and_return(account)
      allow(account).to receive(:cname).and_return('example.test')
      allow(account).to receive(:name).and_return('example')
      allow_any_instance_of(M3ProfileTaskRunner).to receive(:switch!).with(account)
    end

    it 'instantiates the service with audit + update when those are passed' do
      expect(HykuKnapsack::M3ProfileUpdater).to receive(:new)
        .with(action: :audit, revision: :update).and_return(updater)
      expect(updater).to receive(:call).and_return(report)

      expect { invoke_task('example', 'audit', 'update') }.to output(/🚫.*status=no_changes/).to_stdout
    end

    it 'instantiates the service with apply + update' do
      expect(HykuKnapsack::M3ProfileUpdater).to receive(:new)
        .with(action: :apply, revision: :update).and_return(updater)
      expect(updater).to receive(:call).and_return(report.merge(status: :updated))

      expect { invoke_task('example', 'apply', 'update') }.to output(/✅.*status=updated/).to_stdout
    end

    it 'instantiates the service with audit + add' do
      expect(HykuKnapsack::M3ProfileUpdater).to receive(:new)
        .with(action: :audit, revision: :add).and_return(updater)
      expect(updater).to receive(:call).and_return(report.merge(status: :will_add))

      expect { invoke_task('example', 'audit', 'add') }.to output(/⚠️.*status=will_add/).to_stdout
    end

    it 'instantiates the service with apply + add and surfaces the new schema id' do
      expect(HykuKnapsack::M3ProfileUpdater).to receive(:new)
        .with(action: :apply, revision: :add).and_return(updater)
      expect(updater).to receive(:call).and_return(
        report.merge(status: :added, new_schema_id: 42)
      )

      expect { invoke_task('example', 'apply', 'add') }
        .to output(/✅.*status=added.*new_schema=42/).to_stdout
    end

    it 'warns when the name matches no account' do
      allow(Account).to receive(:find_by).with(name: 'unknown').and_return(nil)
      expect { invoke_task('unknown', 'audit', 'update') }
        .to output(/No account matched name="unknown"/).to_stderr
    end
  end

  describe 'all-tenants invocation' do
    let(:tenant_a) { instance_double(Account, name: 'tenant-a', cname: 'a.test') }
    let(:tenant_b) { instance_double(Account, name: 'tenant-b', cname: 'b.test') }
    let(:search_account) { instance_double(Account, name: 'search', cname: 'search.test') }

    before do
      allow(Account).to receive(:find_each).and_yield(tenant_a).and_yield(search_account).and_yield(tenant_b)
      allow_any_instance_of(M3ProfileTaskRunner).to receive(:switch!)
    end

    it 'iterates every account except "search"' do
      expect(updater).to receive(:call).twice.and_return(
        build_report(status: :no_changes, tenant: 'a.test'),
        build_report(status: :no_changes, tenant: 'b.test')
      )

      switched_to = []
      allow_any_instance_of(M3ProfileTaskRunner).to receive(:switch!) { |_runner, account| switched_to << account }

      expect { invoke_task('all', 'audit', 'update') }.to output(/tenant=a.test.*tenant=b.test/m).to_stdout
      expect(switched_to).to eq([tenant_a, tenant_b])
      expect(switched_to).not_to include(search_account)
    end

    it 'continues sweeping after a per-tenant exception' do
      call_count = 0
      allow(updater).to receive(:call) do
        call_count += 1
        raise StandardError, 'simulated failure' if call_count == 1
        build_report(status: :no_changes, tenant: 'b.test')
      end

      expect { invoke_task('all', 'audit', 'update') }
        .to output(/🐛.*status=exception.*\n.*🚫.*tenant=b.test/m).to_stdout
    end
  end

  describe 'emoji selection by service status' do
    let(:account) { instance_double(Account, name: 'example', cname: 'example.test') }

    before do
      allow(Account).to receive(:find_by).with(name: 'example').and_return(account)
      allow_any_instance_of(M3ProfileTaskRunner).to receive(:switch!)
    end

    {
      no_changes: '🚫',
      initialized: '✅',
      updated: '✅',
      added: '✅',
      will_update: '⚠️',
      will_add: '⚠️',
      would_initialize: '⚠️',
      needs_review: '⚠️',
      partial_no_op: '⚠️',
      error: '🐛'
    }.each do |status, emoji|
      it "prefixes the summary with #{emoji} when status is #{status}" do
        allow(updater).to receive(:call).and_return(build_report(status:))
        expect { invoke_task('example', 'audit', 'update') }
          .to output(/^#{Regexp.escape(emoji)} /).to_stdout
      end
    end

    it 'falls back to ⚠️ for an unknown service status' do
      allow(updater).to receive(:call).and_return(build_report(status: :something_new))
      expect { invoke_task('example', 'audit', 'update') }.to output(/^⚠️ /).to_stdout
    end
  end

  describe 'report file output' do
    let(:account) { instance_double(Account, name: 'example', cname: 'example.test') }
    let(:report) { build_report(status: :updated) }

    before do
      allow(Account).to receive(:find_by).with(name: 'example').and_return(account)
      allow_any_instance_of(M3ProfileTaskRunner).to receive(:switch!)
      allow(updater).to receive(:call).and_return(report)
    end

    after do
      FileUtils.rm_rf(M3ProfileTaskRunner.default_report_dir)
    end

    it 'does not write a report file when report arg is omitted' do
      expect do
        invoke_task('example', 'apply', 'update')
      end.not_to change { Dir.glob(M3ProfileTaskRunner.default_report_dir.join('*.yaml')).count }
    end

    it 'does not write a report file when report arg is falsy' do
      expect do
        invoke_task('example', 'apply', 'update', 'no')
      end.not_to change { Dir.glob(M3ProfileTaskRunner.default_report_dir.join('*.yaml')).count }
    end

    %w[true yes 1 report TRUE Yes].each do |truthy|
      it "writes a report file when report arg is #{truthy.inspect}" do
        invoke_task('example', 'apply', 'update', truthy)
        files = Dir.glob(M3ProfileTaskRunner.default_report_dir.join('*.yaml'))
        expect(files).not_to be_empty
        content = YAML.safe_load_file(files.first, permitted_classes: [Symbol])
        expect(content['tenant']).to eq('example.test')
        expect(content['status'].to_s).to include('updated')
      end
    end

    it 'includes the action and revision in the filename' do
      invoke_task('example', 'apply', 'add', 'true')
      files = Dir.glob(M3ProfileTaskRunner.default_report_dir.join('*.yaml'))
      expect(files.first).to match(/-apply-add\.yaml\z/)
    end
  end

  describe 'M3ProfileTaskRunner.truthy?' do
    %w[true TRUE yes YES 1 report].each do |value|
      it "considers #{value.inspect} truthy" do
        expect(M3ProfileTaskRunner.truthy?(value)).to be true
      end
    end

    [nil, '', 'false', '0', 'no', 'off', 'something'].each do |value|
      it "considers #{value.inspect} falsy" do
        expect(M3ProfileTaskRunner.truthy?(value)).to be false
      end
    end
  end

  # Builds a service-shaped report hash. Defaults are "nothing to change"
  # so individual specs only specify the keys they care about.
  def build_report(status:, tenant: 'example.test', schema_id: 1, changes: [], **rest)
    {
      tenant:,
      schema_id:,
      new_schema_id: nil,
      status:,
      action: :audit,
      revision: :update,
      changes:,
      backup_path: nil,
      validation_errors: [],
      schema_initialized: false,
      **rest
    }
  end
end
