# frozen_string_literal: true

module HykuKnapsack
  # Service for surgically modifying a tenant's M3 metadata profile (the
  # Hyrax::FlexibleSchema row in the current Apartment tenant).
  #
  # Two orthogonal axes:
  #
  # action:
  #   :audit  → reports what would change, makes no writes
  #   :apply  → carries out the change (mutating or creating a row depending on revision)
  #
  # revision:
  #   :update → mutate the existing latest Hyrax::FlexibleSchema row in
  #             place. Row id unchanged; existing works on the tenant pick
  #             up the new field definitions on next load. Backup is
  #             written before mutation. This is the "fix-in-place" path.
  #   :add    → create a new Hyrax::FlexibleSchema row containing the
  #             current profile + applied descriptors. New row id surfaces
  #             in the report. Existing works keep pointing at the prior
  #             row (no migration). This is the "new revision going
  #             forward" path. No backup is written because nothing is
  #             overwritten.
  #
  # Usage:
  #   HykuKnapsack::M3ProfileUpdater.new(action: :audit, revision: :update).call
  #   HykuKnapsack::M3ProfileUpdater.new(action: :apply, revision: :update).call
  #   HykuKnapsack::M3ProfileUpdater.new(action: :audit, revision: :add).call
  #   HykuKnapsack::M3ProfileUpdater.new(action: :apply, revision: :add).call
  #
  # The caller is responsible for tenant iteration via Apartment::Tenant.switch.
  # This service operates on whichever tenant context is current when invoked.
  #
  # ## No-profile behavior
  #
  # If the tenant has no Hyrax::FlexibleSchema row at all:
  #   - With action: :audit, returns :would_initialize without doing anything.
  #   - With action: :apply, calls Hyrax::FlexibleSchema.create_default_schema
  #     (loading from the on-disk M3 profile YAML, the same path Hyku uses
  #     when creating a new tenant), then proceeds with the requested
  #     revision against the freshly-initialized row. No backup is written
  #     in this branch since there's no prior state to recover. The
  #     report's :schema_initialized field is set to true.
  #
  # ## Idempotency
  #
  # Both revisions skip the write when descriptors report no pending
  # changes (per-descriptor :already_correct / :already_present /
  # :already_absent). For revision :add specifically, no new row is
  # created if the latest row already matches the desired state — this
  # avoids accumulating redundant revisions.
  #
  # ## CHANGES constant format
  #
  # CHANGES is an array of descriptor hashes. Each descriptor has a :path key
  # (an array of strings naming a walk through the profile YAML, deepest key
  # last) and exactly one mutation key.
  #
  # Supported mutation keys:
  #
  #   { path: %w[...], expected: <val>, new: <val> }
  #     Scalar replace. Updates the value at :path from :expected to :new,
  #     but only if the current value equals :expected. Behavior:
  #     - current == :new       → reported :already_correct, no write
  #     - current == :expected  → updated to :new, reported :updated
  #     - current is anything else → reported :unexpected_value, skipped
  #       (operator investigation; do not stomp tenant customization)
  #     If intermediate keys along :path are missing, the service creates
  #     them as empty hashes during update. In audit mode the descriptor is
  #     reported :will_create_path; in update mode it is reported :updated
  #     once the keys are created and the leaf is set.
  #
  #   { path: %w[...], ensure_includes: <val> }
  #     Array operation. Appends :val to the array at :path if not present.
  #     - :val already in array → reported :already_present
  #     - :val absent           → appended, reported :updated
  #     If the array at :path doesn't exist, the service creates it on
  #     update (treating it as an empty array, then appending).
  #
  #   { path: %w[...], ensure_excludes: <val> }
  #     Array operation. Removes :val from the array at :path if present.
  #     - :val absent   → reported :already_absent
  #     - :val in array → removed, reported :updated
  #
  #   { path: %w[...], ensure_deleted: true }
  #     Removes the key at :path entirely (works on hash keys or array
  #     entries — but typically used on a hash key like a `view:` block).
  #     - key present  → deleted, reported :updated
  #     - key absent   → reported :already_absent
  #     This differs from setting a leaf to nil; the key itself goes away.
  #
  #   { path: %w[properties <prop_name>], ensure_property: <hash> }
  #     Property-level operation. Adds an entire property subtree under
  #     `properties:` if absent; otherwise leaves the existing entry alone.
  #     - property already present → reported :already_present (no write,
  #       no diff — existing tenant customization is preserved)
  #     - property absent          → property hash inserted, reported :updated
  #     This is the only mutation type that intentionally targets a path
  #     where the property does not yet exist — see "Path-missing handling"
  #     below for how the property_missing? gate is bypassed for this case.
  #
  # ### Path-missing handling for property-level paths
  #
  # If a path references a property that doesn't exist at all in the tenant's
  # profile (e.g. the tenant has removed `contributing_library` entirely),
  # the descriptor is reported :path_missing and skipped without erroring.
  # The service does not invent properties via leaf-level mutations. This
  # is distinct from :will_create_path, which only creates intermediate
  # sub-keys *within* an existing property.
  #
  # The check is: if path[0..1] == %w[properties <prop_name>] and
  # profile.dig('properties', prop_name) is nil, the descriptor is
  # :path_missing — except for :ensure_property descriptors, whose entire
  # purpose is to create the missing property.
  #
  # ## Adding new mutations
  #
  # Edit the CHANGES array below. Group related descriptors with section
  # comments. Each descriptor must specify exactly one mutation key.
  # rubocop:disable Metrics/ClassLength
  class M3ProfileUpdater
    CHANGES = [
      # === creator_optional fixes ===

      # form.required: "optional" → false (invalid value corrected)
      { path: %w[properties creator_optional form required],
        expected: "optional",
        new: false },

      # === creator FileSet split ===
      # Move FileSet binding off the shared `creator` entry and onto the
      # relaxed `creator_optional` entry so non-FileSet creators stay required.
      { path: %w[properties creator available_on class],
        ensure_excludes: "Hyrax::FileSet" },
      { path: %w[properties creator_optional available_on class],
        ensure_includes: "Hyrax::FileSet" },

      # === creator GenericWorkResource shift ===
      # Move GenericWorkResource creator from optional (the v6 shape) to
      # required (the new on-disk default).
      { path: %w[properties creator available_on class],
        ensure_includes: "GenericWorkResource" },
      { path: %w[properties creator_optional available_on class],
        ensure_excludes: "GenericWorkResource" },

      # === keyword FileSet split ===
      { path: %w[properties keyword available_on class],
        ensure_excludes: "Hyrax::FileSet" },
      { path: %w[properties keyword_optional available_on class],
        ensure_includes: "Hyrax::FileSet" },

      # === resource_type FileSet split ===
      { path: %w[properties resource_type available_on class],
        ensure_excludes: "Hyrax::FileSet" },
      { path: %w[properties resource_type_optional available_on class],
        ensure_includes: "Hyrax::FileSet" },

      # === contributing_library facet ===
      # Add `facetable` so FlexibleCatalogBehavior registers
      # contributing_library_sim as a facet from M3.
      { path: %w[properties contributing_library indexing],
        ensure_includes: "facetable" },

      # === admin_note editor-only gating ===
      # Replace `admin_only` with `editor_only` on admin_note's indexing
      # array so the field is hidden from non-editor users on show pages
      # and from the catalog index. Requires the Hyrax/Hyku stack to
      # include the upstream `editor_only` filter (so it's recognized
      # and not emitted as a Solr field).
      { path: %w[properties admin_note indexing],
        ensure_includes: "editor_only" },
      { path: %w[properties admin_note indexing],
        ensure_excludes: "admin_only" },

      # === extent view block ===
      # extent had no view: block; adding html_dl: true makes the M3 schema
      # loader include it in view_definitions_for and render it on show pages.
      { path: %w[properties extent view html_dl],
        expected: nil,
        new: true },

      # === hide from catalog search results ===
      # Set `view.search_results: false` on properties we don't want to
      # appear as columns in the catalog search-results listing. Requires
      # the Hyrax FlexibleCatalogBehavior support for the
      # `view.search_results: false` flag (samvera/hyrax#7445).
      # The flag only gates the dynamic add_index_field path inside FCB;
      # any pre-declared static index_field in CatalogController is
      # unaffected.
      { path: %w[properties depositor view search_results],
        expected: nil,
        new: false },
      { path: %w[properties hide_from_catalog_search view search_results],
        expected: nil,
        new: false },
      { path: %w[properties hide_from_catalog_search view show_page],
        expected: nil,
        new: false },
      { path: %w[properties extent view search_results],
        expected: nil,
        new: false },

      # === label editor-only gating ===
      # Label should only appear to users with edit access on the work.
      # Replace `admin_only` with `editor_only` on label's indexing array
      # so the field is restricted via the editor (not admin) permission
      # check — same pattern as admin_note.
      { path: %w[properties label indexing],
        ensure_includes: "editor_only" },
      { path: %w[properties label indexing],
        ensure_excludes: "admin_only" },

      # === depositor admin-only gating ===
      # Depositor should be hidden from both the catalog search results
      # AND the show page for non-admin users. Adding `admin_only` to
      # the indexing array routes through the upstream `restricted_field?`
      # check (evicts from catalog index, facet, qf) AND surfaces
      # admin_only in view_options so the show-page template gates
      # rendering for non-admins. The previously-added view.search_results
      # flag becomes redundant but is left in place.
      { path: %w[properties depositor indexing],
        ensure_includes: "admin_only" },

      # === render_as: linked → faceted ===
      # Properties whose view.render_as flips from "linked" to "faceted"
      # so search-results value clicks apply a facet filter rather than
      # running a fresh keyword search. All these properties already have
      # `facetable` in their indexing array, so the facet target exists.
      { path: %w[properties creator view render_as],
        expected: "linked", new: "faceted" },
      { path: %w[properties creator_optional view render_as],
        expected: "linked", new: "faceted" },
      { path: %w[properties creator_hidden view render_as],
        expected: "linked", new: "faceted" },
      { path: %w[properties contributor view render_as],
        expected: "linked", new: "faceted" },
      { path: %w[properties keyword view render_as],
        expected: "linked", new: "faceted" },
      { path: %w[properties keyword_optional view render_as],
        expected: "linked", new: "faceted" },
      { path: %w[properties language view render_as],
        expected: "linked", new: "faceted" },
      { path: %w[properties publisher view render_as],
        expected: "linked", new: "faceted" },
      { path: %w[properties resource_type view render_as],
        expected: "linked", new: "faceted" },
      { path: %w[properties resource_type_optional view render_as],
        expected: "linked", new: "faceted" },
      { path: %w[properties oer_resource_type view render_as],
        expected: "linked", new: "faceted" },
      { path: %w[properties subject view render_as],
        expected: "linked", new: "faceted" },
      { path: %w[properties dimensions view render_as],
        expected: "linked", new: "faceted" },

      # === flip render_as → faceted for properties already indexing _sim ===
      # These properties have an _sim field in their indexing array (so
      # render_as: faceted has a working facet target) but are currently
      # render_as: linked. Flip the value.
      { path: %w[properties audience view render_as],
        expected: "linked", new: "faceted" },
      { path: %w[properties education_level view render_as],
        expected: "linked", new: "faceted" },
      { path: %w[properties learning_resource_type view render_as],
        expected: "linked", new: "faceted" },

      # === discipline: add the missing _sim Solr field AND render_as: faceted ===
      # discipline currently only indexes discipline_tesim, so the facet
      # link target (discipline_sim) doesn't exist. Two descriptors: add
      # discipline_sim to its indexing array so the Solr field gets
      # written on next index, then create the view.render_as key set
      # to "faceted". Existing OER works need to be reindexed for the
      # facet links to resolve to populated values.
      { path: %w[properties discipline indexing],
        ensure_includes: "discipline_sim" },
      { path: %w[properties discipline view render_as],
        expected: nil, new: "faceted" },

      # === title: remove the view block entirely ===
      # Title's view block (currently `{ html_dl: true }`) is being
      # removed so the M3 schema loader's view_definitions_for filter
      # skips title from show-page rendering. The title still appears
      # via dedicated title-rendering paths (work show header,
      # search-results title link); the row-style rendering on the
      # show page is what gets suppressed.
      { path: %w[properties title view],
        ensure_deleted: true },

      # === redirects: add the property if missing ===
      # The HYRAX_REDIRECTS_ENABLED feature reads a `redirects` property
      # off works and collections. New tenants pick this up via the
      # on-disk m3_profile.yaml; this descriptor backfills the property
      # onto existing tenants whose FlexibleSchema row predates it.
      # Idempotent: if redirects is already present (in any shape — e.g.
      # tenant customization), it's left alone.
      { path: %w[properties redirects],
        ensure_property: {
          'available_on' => { 'class' => %w[GenericWorkResource ImageResource OerResource EtdResource CdlResource CollectionResource] },
          'cardinality' => { 'minimum' => 0 },
          'display_label' => { 'default' => 'Redirects' },
          'type' => 'hash',
          'multiple' => true,
          'form' => { 'display' => false },
          'indexing' => ['editor_only'],
          'predicate' => 'http://samvera.org/ns/hyku/redirects',
          'range' => 'http://www.w3.org/2001/XMLSchema#string',
          'view' => {
            'render_term' => 'redirects_path',
            'render_as' => 'redirects_label',
            'html_dl' => true
          }
        } }
    ].freeze

    BACKUP_DIR = Rails.root.join('tmp', 'imports', 'm3_profile_backups').freeze

    VALID_ACTIONS = %i[audit apply].freeze
    VALID_REVISIONS = %i[update add].freeze

    attr_reader :changes, :tenant_name, :action, :revision

    def initialize(changes: CHANGES, tenant_name: Apartment::Tenant.current,
                   action: :audit, revision: :update)
      raise ArgumentError, "Unknown action: #{action.inspect}" unless VALID_ACTIONS.include?(action)
      raise ArgumentError, "Unknown revision: #{revision.inspect}" unless VALID_REVISIONS.include?(revision)
      @changes = changes
      @tenant_name = tenant_name
      @action = action
      @revision = revision
    end

    # Run the service. Behavior depends on the (action, revision) pair
    # passed to the constructor — see class docs for the full matrix.
    #
    # @return [Hash] structured report. See class docs for fields.
    def call
      run
    end

    private

    # rubocop:disable Metrics/MethodLength
    def run
      schema = Hyrax::FlexibleSchema.order(:created_at).last
      schema_was_initialized = false

      if schema.blank?
        return report_would_initialize unless action == :apply
        schema = Hyrax::FlexibleSchema.create_default_schema
        schema_was_initialized = true
      end

      profile = deep_dup_profile(schema.profile)
      results = changes.map { |descriptor| evaluate(descriptor, profile) }

      pending = results.any? { |r| r[:status] == :will_update }

      if action == :apply && pending
        apply_changes(schema, profile, results, schema_was_initialized)
      else
        finalize_report(schema, results, schema_was_initialized:, new_schema_id: nil, backup_path: nil)
      end
    end
    # rubocop:enable Metrics/MethodLength

    # Apply pending changes per the revision strategy. Returns a finalized
    # report; on validation failure returns an error report.
    # rubocop:disable Metrics/MethodLength
    def apply_changes(schema, profile, results, schema_was_initialized)
      results = results.map { |r| apply(r, profile) }

      if revision == :update
        # Mutate the existing row in place. Skip backup when we just
        # initialized the row — there's no prior state to recover.
        backup_path = schema_was_initialized ? nil : write_backup(schema.profile)
        schema.profile = profile
        begin
          schema.save!
        rescue ActiveRecord::RecordInvalid => e
          return error_report(schema, results, e, schema_was_initialized:, new_schema_id: nil, backup_path:)
        end
        finalize_report(schema, results, schema_was_initialized:, new_schema_id: nil, backup_path:)
      else
        # revision == :add: create a new row with the updated profile.
        # The existing row is left untouched. No backup is needed since
        # nothing is overwritten.
        new_schema = Hyrax::FlexibleSchema.new(profile:)
        begin
          new_schema.save!
        rescue ActiveRecord::RecordInvalid => e
          return error_report(schema, results, e, schema_was_initialized:, new_schema_id: nil, backup_path: nil)
        end
        finalize_report(schema, results, schema_was_initialized:, new_schema_id: new_schema.id, backup_path: nil)
      end
    end
    # rubocop:enable Metrics/MethodLength

    # Examines one descriptor against the in-memory profile hash and
    # returns a result hash describing what status applies, without
    # mutating the profile.
    #
    # In audit-action runs, scalar :set descriptors that would create new
    # intermediate keys are reported :will_create_path so the operator
    # sees that the path doesn't exist yet. In apply-action runs the same
    # case is reported as :will_update (it will be created during apply).
    # rubocop:disable Metrics/MethodLength
    def evaluate(descriptor, profile)
      path = descriptor[:path]
      base = { path: path.join('.'), descriptor: }

      type = mutation_type(descriptor)
      return base.merge(status: :path_missing, applied: false) if property_missing?(profile, path, type)

      case type
      when :set
        evaluate_set(descriptor, profile, base)
      when :include
        evaluate_include(descriptor, profile, base)
      when :exclude
        evaluate_exclude(descriptor, profile, base)
      when :delete
        evaluate_delete(descriptor, profile, base)
      when :property
        evaluate_property(descriptor, profile, base)
      end
    end
    # rubocop:enable Metrics/MethodLength

    def evaluate_set(descriptor, profile, base)
      expected = descriptor[:expected]
      new_value = descriptor[:new]
      current_present, current = lookup(profile, descriptor[:path])

      if current_present && current == new_value
        base.merge(status: :already_correct, current:, applied: false)
      elsif current_present && current == expected
        base.merge(status: :will_update, current:, new: new_value, applied: false)
      elsif !current_present && expected.nil?
        # Path doesn't exist and that's the expected starting state.
        status = action == :audit ? :will_create_path : :will_update
        base.merge(status:, current: nil, new: new_value, applied: false)
      else
        base.merge(status: :unexpected_value, current:, applied: false)
      end
    end

    def evaluate_include(descriptor, profile, base)
      value = descriptor[:ensure_includes]
      current_present, current = lookup(profile, descriptor[:path])
      arr = current_present ? Array(current) : []

      if arr.include?(value)
        base.merge(status: :already_present, current: arr, applied: false)
      else
        base.merge(status: :will_update, current: arr, value:, applied: false)
      end
    end

    def evaluate_exclude(descriptor, profile, base)
      value = descriptor[:ensure_excludes]
      current_present, current = lookup(profile, descriptor[:path])
      arr = current_present ? Array(current) : []

      if arr.include?(value)
        base.merge(status: :will_update, current: arr, value:, applied: false)
      else
        base.merge(status: :already_absent, current: arr, applied: false)
      end
    end

    def evaluate_delete(descriptor, profile, base)
      current_present, current = lookup(profile, descriptor[:path])

      if current_present
        base.merge(status: :will_update, current:, applied: false)
      else
        base.merge(status: :already_absent, current: nil, applied: false)
      end
    end

    def evaluate_property(descriptor, profile, base)
      current_present, current = lookup(profile, descriptor[:path])

      if current_present
        base.merge(status: :already_present, current:, applied: false)
      else
        base.merge(status: :will_update, current: nil, new: descriptor[:ensure_property], applied: false)
      end
    end

    # Apply one evaluated descriptor's mutation to the in-memory profile.
    # Only descriptors with status :will_update produce changes; everything
    # else is passed through with applied: false and the status preserved.
    # rubocop:disable Metrics/MethodLength
    def apply(result, profile)
      return result unless result[:status] == :will_update

      descriptor = result[:descriptor]
      case mutation_type(descriptor)
      when :set
        write(profile, descriptor[:path], descriptor[:new])
      when :include
        arr = read_or_create_array(profile, descriptor[:path])
        arr << descriptor[:ensure_includes] unless arr.include?(descriptor[:ensure_includes])
      when :exclude
        _present, current = lookup(profile, descriptor[:path])
        arr = Array(current)
        arr.delete(descriptor[:ensure_excludes])
        write(profile, descriptor[:path], arr)
      when :delete
        delete_at(profile, descriptor[:path])
      when :property
        write(profile, descriptor[:path], descriptor[:ensure_property])
      end

      result.merge(status: :updated, applied: true)
    end
    # rubocop:enable Metrics/MethodLength

    # Walk the profile hash along path, returning [found?, value].
    # found? is false if any segment along the path doesn't exist.
    def lookup(profile, path)
      current = profile
      path.each do |segment|
        return [false, nil] unless current.is_a?(Hash) && current.key?(segment)
        current = current[segment]
      end
      [true, current]
    end

    # Set a leaf value at path, creating intermediate hashes as needed.
    def write(profile, path, value)
      *intermediate, leaf = path
      target = intermediate.inject(profile) do |hash, segment|
        hash[segment] ||= {}
        hash[segment]
      end
      target[leaf] = value
    end

    # For ensure_includes: ensure an array exists at path, creating
    # intermediate hashes and the array itself as needed. Returns the
    # array so the caller can mutate it in place.
    def read_or_create_array(profile, path)
      *intermediate, leaf = path
      target = intermediate.inject(profile) do |hash, segment|
        hash[segment] ||= {}
        hash[segment]
      end
      target[leaf] = Array(target[leaf]) unless target[leaf].is_a?(Array)
      target[leaf]
    end

    # Delete the key at path. No-op if any intermediate segment is missing.
    def delete_at(profile, path)
      *intermediate, leaf = path
      parent = intermediate.inject(profile) do |hash, segment|
        return nil unless hash.is_a?(Hash) && hash.key?(segment)
        hash[segment]
      end
      parent&.delete(leaf)
    end

    # A property is considered missing if path[0..1] is ["properties", X]
    # and profile["properties"][X] is nil. Paths that don't begin with
    # "properties" are not gated this way. The :property mutation type
    # is exempt — its entire purpose is to create the missing property.
    def property_missing?(profile, path, mutation = nil)
      return false if mutation == :property
      return false unless path[0] == 'properties' && path.length >= 2
      properties = profile['properties']
      properties.nil? || !properties.key?(path[1])
    end

    def mutation_type(descriptor)
      return :set if descriptor.key?(:new)
      return :include if descriptor.key?(:ensure_includes)
      return :exclude if descriptor.key?(:ensure_excludes)
      return :delete if descriptor.key?(:ensure_deleted)
      return :property if descriptor.key?(:ensure_property)
      raise ArgumentError, "Descriptor missing mutation key: #{descriptor.inspect}"
    end

    # The Hyrax::FlexibleSchema row stores `profile` as a serialized YAML
    # hash. To stay safe under successive mutations, deep-dup before
    # editing so the original row isn't mutated until save!.
    def deep_dup_profile(profile)
      YAML.safe_load(YAML.dump(profile), permitted_classes: [Symbol, Date, Time])
    end

    def write_backup(profile)
      FileUtils.mkdir_p(BACKUP_DIR)
      timestamp = Time.zone.now.strftime('%Y%m%d-%H%M%S')
      path = BACKUP_DIR.join("#{tenant_name}-#{timestamp}.yaml")
      File.write(path, YAML.dump(profile))
      path.to_s
    end

    # Audit-action response when no profile row exists for this tenant.
    # Apply-action runs never reach this path because they initialize the
    # default schema before evaluating descriptors.
    def report_would_initialize
      {
        tenant: tenant_name,
        schema_id: nil,
        new_schema_id: nil,
        status: :would_initialize,
        action:,
        revision:,
        changes: [],
        backup_path: nil,
        validation_errors: [],
        schema_initialized: false
      }
    end

    def finalize_report(schema, results, schema_was_initialized:, new_schema_id:, backup_path:)
      {
        tenant: tenant_name,
        schema_id: schema.id,
        new_schema_id:,
        status: overall_status(results, schema_was_initialized, new_schema_id, backup_path),
        action:,
        revision:,
        changes: results,
        backup_path:,
        validation_errors: [],
        schema_initialized: schema_was_initialized
      }
    end

    # rubocop:disable Metrics/ParameterLists
    def error_report(schema, results, exception, schema_was_initialized:, new_schema_id:, backup_path:)
      {
        tenant: tenant_name,
        schema_id: schema.id,
        new_schema_id:,
        status: :error,
        action:,
        revision:,
        changes: results,
        backup_path:,
        validation_errors: Array(exception.record&.errors&.full_messages),
        schema_initialized: schema_was_initialized
      }
    end
    # rubocop:enable Metrics/ParameterLists

    # rubocop:disable Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
    def overall_status(results, schema_was_initialized, new_schema_id, backup_path)
      applied_any = results.any? { |r| r[:applied] }

      if applied_any && new_schema_id
        :added
      elsif applied_any && (backup_path || schema_was_initialized)
        :updated
      elsif schema_was_initialized
        :initialized
      elsif results.any? { |r| r[:status] == :unexpected_value }
        :needs_review
      elsif results.any? { |r| r[:status] == :path_missing }
        :partial_no_op
      elsif results.any? { |r| %i[will_update will_create_path].include?(r[:status]) }
        # Audit-action found pending changes. Distinguish add vs update so
        # operators can see at a glance whether the apply would mutate the
        # row in place or create a new revision row.
        revision == :add ? :will_add : :will_update
      else
        :no_changes
      end
    end
    # rubocop:enable Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
  end
  # rubocop:enable Metrics/ClassLength
end
