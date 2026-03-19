# frozen_string_literal: true

# OVERRIDE IIIF Print v1.0.0 to call CreateGroupAndAddMembersJob
# Define at IiifPrint::CreateRelationshipsJobDecorator for Zeitwerk (path: jobs/iiif_print/create_relationships_job_decorator.rb)
module IiifPrint
  module CreateRelationshipsJobDecorator
    # rubocop:disable Metrics/MethodLength
    def perform(parent_id:, parent_model:, child_model:, retries: 0, **)
      @parent_id = parent_id
      @parent_model = parent_model
      @child_model = child_model
      @retries = retries + 1

      @number_of_successes = 0
      @number_of_failures = 0
      @parent_record_members_added = false
      @errors = []

      # Because we need our children in the correct order, we can't create any
      # relationships until all child works have been created.
      if completed_child_data
        # add the members
        add_children_to_parent
        if @number_of_failures.zero? && @number_of_successes == @pending_children.count
          # remove pending relationships upon valid completion
          @pending_children.each(&:destroy)
        elsif @number_of_failures.zero? && @number_of_successes > @pending_children.count
          # remove pending relationships but raise error that too many relationships formed
          @pending_children.each(&:destroy)
          raise "CreateRelationshipsJob for parent id: #{@parent_id} " \
                "added #{@number_of_successes} children, " \
                "expected #{@pending_children} children."
        else
          # report failures & keep pending relationships
          raise "CreateRelationshipsJob failed for parent id: #{@parent_id} " \
                "had #{@number_of_successes} successes & #{@number_of_failures} failures, " \
                "with errors: #{@errors}. Wanted #{@pending_children.count} children."
        end

        # OVERRIDE begin
        CreateGroupAndAddMembersJob.set(wait: 2.minutes).perform_later(parent_id) if parent_model == 'Cdl'
        # OVERRIDE end
      else
        # if we aren't ready yet, reschedule the job and end this one normally
        reschedule_job
      end
    end
  end
end

IiifPrint::Jobs::CreateRelationshipsJob.prepend(IiifPrint::CreateRelationshipsJobDecorator)
