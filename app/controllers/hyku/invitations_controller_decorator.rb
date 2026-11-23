# frozen_string_literal: true

# OVERRIDE Hyku v7.1.0 Hyku::InvitationsController#create: resend the invitation when the user is still pending.
#   The invite form says it can resend an invitation, but create only invited users it could not find,
#   so inviting a pending user again reported success and sent nothing (notch8/palni_palci_knapsack#952).
#   Remove once the fix reaches this knapsack through a Hyku bump.
module Hyku
  module InvitationsControllerDecorator
    def create
      pending_user = User.find_by(email: params.dig(:user, :email))
      super
      # Locked so a concurrent Activate cannot leave this holding a stale pending state
      pending_user&.with_lock { pending_user.invite!(current_inviter) if pending_user.invited_to_sign_up? }
    end
  end
end

Hyku::InvitationsController.prepend(Hyku::InvitationsControllerDecorator)
