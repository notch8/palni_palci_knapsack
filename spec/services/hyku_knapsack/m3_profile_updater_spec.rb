# frozen_string_literal: true

require 'rails_helper'

# A comprehensive spec for the M3ProfileUpdater service. This ensures that
# default m3 profile remains conformant to the structure expected by this
# updater service. If this spec fails, either the on-disk YAML was edited
# in a way that no longer matches the descriptors or a descriptor was
# added/changed without updating the YAML.

# If this becomes problematic, we can add a skip, but initially this is helpful
# to ensure that we don't make unintentional changes to the default profile, as
# well as to validate that if we DO migrate the profiles for everyone, we don't
# forget to also update the default m3_profile.yaml to match the new shape.
RSpec.describe HykuKnapsack::M3ProfileUpdater do
  # Use the on-disk profile as the canonical "already correct" state: the
  # CHANGES constant describes mutations that bring an older profile up to
  # what's in config/metadata_profiles/m3_profile.yaml today, so a tenant
  # whose row matches the on-disk file is by construction already correct.
  let(:profile_path) { HykuKnapsack::Engine.root.join('config', 'metadata_profiles', 'm3_profile.yaml') }
  let(:on_disk_profile) { YAML.safe_load_file(profile_path) }

  # A "pre-#597" profile shape — what a tenant looked like before the M3
  # changes landed. Built by mutating the on-disk profile in reverse so
  # the descriptors all have work to do.
  let(:pre_597_profile) do
    profile = deep_dup(on_disk_profile)

    # Reverse creator_optional.form.required: false → "optional"
    profile['properties']['creator_optional']['form']['required'] = 'optional'

    # Reverse the FileSet split
    %w[creator keyword resource_type].each do |prop|
      profile['properties'][prop]['available_on']['class'] |= ['Hyrax::FileSet']
      profile['properties']["#{prop}_optional"]['available_on']['class'].delete('Hyrax::FileSet')
    end

    profile['properties']['contributing_library']['indexing'].delete('facetable')
    profile['properties']['extent'].delete('view')
    profile['properties'].delete('redirects')

    profile
  end

  before do
    Hyrax::FlexibleSchema.delete_all
  end

  def deep_dup(profile)
    YAML.safe_load(YAML.dump(profile), permitted_classes: [Symbol, Date, Time])
  end

  describe 'constructor validation' do
    it 'raises on an unknown action' do
      expect { described_class.new(action: :bogus, revision: :update) }
        .to raise_error(ArgumentError, /Unknown action/)
    end

    it 'raises on an unknown revision' do
      expect { described_class.new(action: :audit, revision: :bogus) }
        .to raise_error(ArgumentError, /Unknown revision/)
    end
  end

  # === audit + update ===========================================================
  # The historical "what would change in place" preview.
  describe 'action: :audit, revision: :update' do
    let(:service) { described_class.new(action: :audit, revision: :update) }

    context 'when no profile row exists' do
      it 'returns :would_initialize and does not create a row' do
        expect do
          report = service.call
          expect(report[:status]).to eq(:would_initialize)
          expect(report[:schema_id]).to be_nil
          expect(report[:new_schema_id]).to be_nil
          expect(report[:changes]).to be_empty
          expect(report[:backup_path]).to be_nil
          expect(report[:schema_initialized]).to be false
          expect(report[:action]).to eq(:audit)
          expect(report[:revision]).to eq(:update)
        end.not_to change(Hyrax::FlexibleSchema, :count)
      end
    end

    context 'when the profile already matches the on-disk default' do
      before { Hyrax::FlexibleSchema.create!(profile: deep_dup(on_disk_profile)) }

      it 'reports :no_changes and makes no database writes' do
        original_profile = deep_dup(Hyrax::FlexibleSchema.last.profile)

        report = service.call

        expect(report[:status]).to eq(:no_changes)
        expect(report[:changes]).to all(satisfy do |c|
          %i[already_correct already_present already_absent].include?(c[:status])
        end)
        expect(Hyrax::FlexibleSchema.count).to eq(1)
        expect(Hyrax::FlexibleSchema.last.profile).to eq(original_profile)
      end
    end

    context 'when the profile is in a pre-#597 state' do
      before { Hyrax::FlexibleSchema.create!(profile: pre_597_profile) }

      it 'reports :will_update without persisting' do
        expect do
          report = service.call

          expect(report[:changes].map { |c| c[:status] }).to all(
            satisfy do |status|
              %i[will_update will_create_path already_correct already_present already_absent].include?(status)
            end
          )
          expect(report[:changes].map { |c| c[:status] }).to include(:will_update)
          expect(report[:backup_path]).to be_nil
          expect(report[:status]).to eq(:will_update)
        end.not_to change { Hyrax::FlexibleSchema.last.profile }
      end
    end

    context 'when a descriptor has an unexpected value' do
      before do
        profile = deep_dup(pre_597_profile)
        profile['properties']['creator_optional']['form']['required'] = true
        Hyrax::FlexibleSchema.create!(profile:)
      end

      it 'flags the descriptor as :unexpected_value and reports :needs_review' do
        report = service.call

        unexpected = report[:changes].find { |c| c[:path] == 'properties.creator_optional.form.required' }
        expect(unexpected[:status]).to eq(:unexpected_value)
        expect(report[:status]).to eq(:needs_review)
      end
    end

    context 'when a targeted property is missing entirely' do
      before do
        profile = deep_dup(pre_597_profile)
        profile['properties'].delete('contributing_library')
        Hyrax::FlexibleSchema.create!(profile:)
      end

      it 'reports :path_missing for the missing property' do
        report = service.call

        missing = report[:changes].find { |c| c[:path] == 'properties.contributing_library.indexing' }
        expect(missing[:status]).to eq(:path_missing)
      end
    end

    context 'when an intermediate path key is missing but the property exists' do
      before do
        profile = deep_dup(on_disk_profile)
        profile['properties']['extent'].delete('view')
        Hyrax::FlexibleSchema.create!(profile:)
      end

      it 'reports :will_create_path on audit (not :path_missing)' do
        report = service.call

        entry = report[:changes].find { |c| c[:path] == 'properties.extent.view.html_dl' }
        expect(entry[:status]).to eq(:will_create_path)
      end
    end
  end

  # === apply + update ==========================================================
  # The historical "mutate the row in place" path.
  describe 'action: :apply, revision: :update' do
    let(:service) { described_class.new(action: :apply, revision: :update) }

    context 'when no profile row exists' do
      it 'initializes the default schema and reports :initialized' do
        expect do
          report = service.call

          expect(report[:status]).to eq(:initialized)
          expect(report[:schema_initialized]).to be true
          expect(report[:schema_id]).to be_present
          expect(report[:new_schema_id]).to be_nil
          expect(report[:backup_path]).to be_nil
        end.to change(Hyrax::FlexibleSchema, :count).from(0).to(1)
      end
    end

    context 'when the profile already matches the on-disk default' do
      before { Hyrax::FlexibleSchema.create!(profile: deep_dup(on_disk_profile)) }

      it 'reports :no_changes and writes nothing' do
        original_profile = deep_dup(Hyrax::FlexibleSchema.last.profile)

        report = service.call

        expect(report[:status]).to eq(:no_changes)
        expect(report[:backup_path]).to be_nil
        expect(Hyrax::FlexibleSchema.count).to eq(1)
        expect(Hyrax::FlexibleSchema.last.profile).to eq(original_profile)
      end
    end

    context 'when the profile is in a pre-#597 state' do
      let!(:schema) { Hyrax::FlexibleSchema.create!(profile: pre_597_profile) }

      it 'applies changes in place without creating a new row' do
        expect { service.call }.not_to change(Hyrax::FlexibleSchema, :count)
      end

      it 'preserves the row id and persists the new profile' do
        original_id = schema.id
        service.call

        schema.reload
        expect(schema.id).to eq(original_id)
        expect(schema.profile['properties']['creator_optional']['form']['required']).to eq(false)
        expect(schema.profile['properties']['contributing_library']['indexing']).to include('facetable')
        expect(schema.profile['properties']['extent']['view']).to include('html_dl' => true)
      end

      it 'writes a backup file to BACKUP_DIR' do
        service.call
        backup_files = Dir.glob(described_class::BACKUP_DIR.join('*.yaml'))
        expect(backup_files).not_to be_empty
        latest = backup_files.max_by { |f| File.mtime(f) }
        backup_content = YAML.safe_load_file(latest)
        expect(backup_content['properties']['creator_optional']['form']['required']).to eq('optional')
      ensure
        FileUtils.rm_rf(described_class::BACKUP_DIR)
      end

      it 'reports :updated with applied: true on each mutating change' do
        report = service.call

        expect(report[:status]).to eq(:updated)
        mutating = report[:changes].select do |c|
          %i[will_update will_create_path].include?(c[:status]) ||
            c[:status] == :updated
        end
        expect(mutating).not_to be_empty
        expect(mutating.map { |c| c[:applied] }).to all(be true)
        expect(report[:backup_path]).to be_present
        expect(report[:new_schema_id]).to be_nil
      ensure
        FileUtils.rm_rf(described_class::BACKUP_DIR)
      end

      context 'when run twice (idempotency)' do
        it 'makes no changes on the second invocation and writes no second backup' do
          service.call
          first_count = Dir.glob(described_class::BACKUP_DIR.join('*.yaml')).count

          schema.reload
          profile_after_first = deep_dup(schema.profile)

          report = described_class.new(action: :apply, revision: :update).call

          expect(report[:status]).to eq(:no_changes)
          expect(report[:backup_path]).to be_nil
          expect(schema.reload.profile).to eq(profile_after_first)
          expect(Dir.glob(described_class::BACKUP_DIR.join('*.yaml')).count).to eq(first_count)
        ensure
          FileUtils.rm_rf(described_class::BACKUP_DIR)
        end
      end
    end

    context 'when validation fails on save' do
      let!(:schema) { Hyrax::FlexibleSchema.create!(profile: pre_597_profile) }

      before do
        allow_any_instance_of(Hyrax::FlexibleSchema).to receive(:save!).and_wrap_original do |original, *_args|
          record = original.receiver
          record.errors.add(:profile, 'fabricated validation failure')
          raise ActiveRecord::RecordInvalid, record
        end
      end

      it 'returns :error and the profile is not persisted' do
        original_profile = deep_dup(schema.profile)

        report = service.call

        expect(report[:status]).to eq(:error)
        expect(report[:validation_errors]).to include(match(/fabricated validation failure/))
        expect(schema.reload.profile).to eq(original_profile)
      ensure
        FileUtils.rm_rf(described_class::BACKUP_DIR)
      end
    end
  end

  # === audit + add =============================================================
  # Preview what a new revision row would contain.
  describe 'action: :audit, revision: :add' do
    let(:service) { described_class.new(action: :audit, revision: :add) }

    context 'when the profile already matches the on-disk default' do
      before { Hyrax::FlexibleSchema.create!(profile: deep_dup(on_disk_profile)) }

      it 'reports :no_changes (no new row would be created)' do
        original_count = Hyrax::FlexibleSchema.count

        report = service.call

        expect(report[:status]).to eq(:no_changes)
        expect(report[:new_schema_id]).to be_nil
        expect(Hyrax::FlexibleSchema.count).to eq(original_count)
      end
    end

    context 'when the profile is in a pre-#597 state' do
      before { Hyrax::FlexibleSchema.create!(profile: pre_597_profile) }

      it 'reports :will_add without persisting' do
        expect do
          report = service.call

          expect(report[:status]).to eq(:will_add)
          expect(report[:revision]).to eq(:add)
          expect(report[:action]).to eq(:audit)
          expect(report[:new_schema_id]).to be_nil
          expect(report[:backup_path]).to be_nil
        end.not_to change(Hyrax::FlexibleSchema, :count)
      end
    end
  end

  # === apply + add =============================================================
  # Create a new revision row carrying the desired profile state.
  describe 'action: :apply, revision: :add' do
    let(:service) { described_class.new(action: :apply, revision: :add) }

    context 'when the profile already matches the on-disk default' do
      before { Hyrax::FlexibleSchema.create!(profile: deep_dup(on_disk_profile)) }

      it 'reports :no_changes and does not create a new row' do
        expect { service.call }.not_to change(Hyrax::FlexibleSchema, :count)
      end
    end

    context 'when the profile is in a pre-#597 state' do
      let!(:schema) { Hyrax::FlexibleSchema.create!(profile: pre_597_profile) }

      it 'creates a new row with the descriptors applied; old row is preserved' do
        original_id = schema.id
        original_profile = deep_dup(schema.profile)

        expect { service.call }.to change(Hyrax::FlexibleSchema, :count).by(1)

        # Old row is untouched.
        schema.reload
        expect(schema.id).to eq(original_id)
        expect(schema.profile).to eq(original_profile)

        # New row carries the applied changes.
        new_row = Hyrax::FlexibleSchema.order(:created_at).last
        expect(new_row.id).not_to eq(original_id)
        expect(new_row.profile['properties']['creator_optional']['form']['required']).to eq(false)
        expect(new_row.profile['properties']['contributing_library']['indexing']).to include('facetable')
        expect(new_row.profile['properties']['extent']['view']).to include('html_dl' => true)
      end

      it 'reports :added with the new schema id and no backup' do
        report = service.call

        expect(report[:status]).to eq(:added)
        expect(report[:revision]).to eq(:add)
        expect(report[:action]).to eq(:apply)
        expect(report[:schema_id]).to eq(schema.id)
        new_row = Hyrax::FlexibleSchema.order(:created_at).last
        expect(report[:new_schema_id]).to eq(new_row.id)
        expect(report[:backup_path]).to be_nil
        mutating = report[:changes].select do |c|
          %i[will_update will_create_path].include?(c[:status]) ||
            c[:status] == :updated
        end
        expect(mutating).not_to be_empty
        expect(mutating.map { |c| c[:applied] }).to all(be true)
      end

      context 'when run twice (idempotency)' do
        it 'does not create a second new row when the latest already matches' do
          service.call
          count_after_first = Hyrax::FlexibleSchema.count

          report = described_class.new(action: :apply, revision: :add).call

          expect(Hyrax::FlexibleSchema.count).to eq(count_after_first)
          expect(report[:status]).to eq(:no_changes)
          expect(report[:new_schema_id]).to be_nil
        end
      end
    end

    context 'when validation fails on save of the new row' do
      let!(:schema) { Hyrax::FlexibleSchema.create!(profile: pre_597_profile) }

      before do
        # Force only NEW (unpersisted) records' save! to raise. We allow the
        # `let!` create above to run first, then install the stub.
        allow_any_instance_of(Hyrax::FlexibleSchema).to receive(:save!).and_wrap_original do |original, *_args|
          record = original.receiver
          if record.persisted?
            original.call
          else
            record.errors.add(:profile, 'fabricated validation failure')
            raise ActiveRecord::RecordInvalid, record
          end
        end
      end

      it 'returns :error and does not create a new row' do
        expect { service.call }.not_to change(Hyrax::FlexibleSchema, :count)

        report = described_class.new(action: :apply, revision: :add).call
        expect(report[:status]).to eq(:error)
        expect(report[:validation_errors]).to include(match(/fabricated validation failure/))
        expect(report[:new_schema_id]).to be_nil
      end
    end
  end

  # === cross-cutting ============================================================
  describe 'tenant context' do
    before { Hyrax::FlexibleSchema.create!(profile: deep_dup(on_disk_profile)) }

    it 'defaults to Apartment::Tenant.current' do
      allow(Apartment::Tenant).to receive(:current).and_return('example-tenant.test')
      report = described_class.new(action: :audit, revision: :update).call
      expect(report[:tenant]).to eq('example-tenant.test')
    end

    it 'accepts an explicit tenant_name override' do
      report = described_class.new(tenant_name: 'custom-tenant.test', action: :audit, revision: :update).call
      expect(report[:tenant]).to eq('custom-tenant.test')
    end
  end

  describe 'CHANGES constant' do
    it 'has every descriptor with a :path and exactly one mutation key' do
      mutation_keys = %i[new ensure_includes ensure_excludes ensure_deleted ensure_property]

      described_class::CHANGES.each do |descriptor|
        expect(descriptor).to have_key(:path)
        expect(descriptor[:path]).to be_an(Array)

        present = mutation_keys.count { |k| descriptor.key?(k) }
        expect(present).to eq(1), "Descriptor #{descriptor.inspect} must have exactly one of #{mutation_keys.inspect}"

        expect(descriptor).to have_key(:expected) if descriptor.key?(:new)
      end
    end
  end

  # Guards against drift between the descriptor list and the on-disk
  # default profile. The on-disk YAML is the source of truth for what a
  # freshly-initialized tenant lands on, so every CHANGES descriptor must
  # report a "no work to do" status when audited against it. If this spec
  # fails, either a descriptor was added/changed without updating the YAML
  # or the YAML was edited in a way that no longer matches the descriptors.
  describe 'on-disk profile conformance' do
    let(:no_op_statuses) { %i[already_correct already_present already_absent] }

    before do
      Hyrax::FlexibleSchema.create!(profile: on_disk_profile)
    end

    it 'reports no pending changes for every descriptor when audited against the on-disk YAML' do
      report = described_class.new(action: :audit, revision: :update).call

      expect(report[:status]).to eq(:no_changes)

      drifted = report[:changes].reject { |c| no_op_statuses.include?(c[:status]) }
      expect(drifted).to be_empty,
                         'Descriptors out of sync with config/metadata_profiles/m3_profile.yaml: ' \
                         "#{drifted.map { |c| "#{c[:path]} → #{c[:status]}" }.join('; ')}"
    end
  end

  describe 'ensure_deleted mutation' do
    let(:custom_changes) do
      [{ path: %w[properties extent view], ensure_deleted: true }]
    end

    context 'audit when the key exists' do
      before do
        profile = deep_dup(on_disk_profile)
        # Make sure extent.view exists for the test
        profile['properties']['extent']['view'] ||= { 'html_dl' => true }
        Hyrax::FlexibleSchema.create!(profile:)
      end

      it 'reports :will_update' do
        report = described_class.new(
          changes: custom_changes, action: :audit, revision: :update
        ).call
        entry = report[:changes].first
        expect(entry[:status]).to eq(:will_update)
      end
    end

    context 'audit when the key is already absent' do
      before do
        profile = deep_dup(on_disk_profile)
        profile['properties']['extent'].delete('view')
        Hyrax::FlexibleSchema.create!(profile:)
      end

      it 'reports :already_absent' do
        report = described_class.new(
          changes: custom_changes, action: :audit, revision: :update
        ).call
        entry = report[:changes].first
        expect(entry[:status]).to eq(:already_absent)
      end
    end

    context 'apply removes the key' do
      let!(:schema) do
        profile = deep_dup(on_disk_profile)
        profile['properties']['extent']['view'] ||= { 'html_dl' => true }
        Hyrax::FlexibleSchema.create!(profile:)
      end

      it 'deletes the key from the profile' do
        described_class.new(
          changes: custom_changes, action: :apply, revision: :update
        ).call
        schema.reload
        expect(schema.profile['properties']['extent']).not_to have_key('view')
      ensure
        FileUtils.rm_rf(described_class::BACKUP_DIR)
      end
    end
  end

  describe 'ensure_property mutation' do
    let(:property_hash) do
      {
        'available_on' => { 'class' => %w[GenericWorkResource] },
        'display_label' => { 'default' => 'Example' },
        'range' => 'http://www.w3.org/2001/XMLSchema#string',
        'type' => 'hash'
      }
    end
    let(:custom_changes) do
      [{ path: %w[properties example_redirects], ensure_property: property_hash }]
    end

    context 'audit when the property is absent' do
      before do
        profile = deep_dup(on_disk_profile)
        profile['properties'].delete('example_redirects')
        Hyrax::FlexibleSchema.create!(profile:)
      end

      it 'reports :will_update (not :path_missing)' do
        report = described_class.new(
          changes: custom_changes, action: :audit, revision: :update
        ).call
        entry = report[:changes].first
        expect(entry[:status]).to eq(:will_update)
      end
    end

    context 'audit when the property is already present' do
      before do
        profile = deep_dup(on_disk_profile)
        profile['properties']['example_redirects'] = property_hash
        Hyrax::FlexibleSchema.create!(profile:)
      end

      it 'reports :already_present and leaves the existing entry alone' do
        report = described_class.new(
          changes: custom_changes, action: :audit, revision: :update
        ).call
        entry = report[:changes].first
        expect(entry[:status]).to eq(:already_present)
      end
    end

    context 'apply inserts the property when absent' do
      let!(:schema) do
        profile = deep_dup(on_disk_profile)
        profile['properties'].delete('example_redirects')
        Hyrax::FlexibleSchema.create!(profile:)
      end

      it 'adds the property hash to the profile' do
        described_class.new(
          changes: custom_changes, action: :apply, revision: :update
        ).call
        schema.reload
        expect(schema.profile['properties']['example_redirects']).to eq(property_hash)
      ensure
        FileUtils.rm_rf(described_class::BACKUP_DIR)
      end
    end

    context 'apply preserves existing tenant customization when property already present' do
      let(:tenant_custom) { property_hash.merge('display_label' => { 'default' => 'Tenant Custom' }) }
      let!(:schema) do
        profile = deep_dup(on_disk_profile)
        profile['properties']['example_redirects'] = tenant_custom
        Hyrax::FlexibleSchema.create!(profile:)
      end

      it 'does not overwrite the existing property' do
        described_class.new(
          changes: custom_changes, action: :apply, revision: :update
        ).call
        schema.reload
        expect(schema.profile['properties']['example_redirects']).to eq(tenant_custom)
      end
    end
  end
end
