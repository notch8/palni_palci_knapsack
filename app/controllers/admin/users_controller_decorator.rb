# frozen_string_literal: true

# OVERRIDE Hyku v7.1.0 Admin::UsersController#activate: only act on a pending user of this repository,
#   and email them a link to set their own password. Activating consumes the invitation and assigns a
#   password the user does not know, which left invitees locked out with "invitation token invalid"
#   (notch8/palni_palci_knapsack#952). Remove once samvera/hyku#3578 reaches this knapsack.
module Admin
  module UsersControllerDecorator
    def activate
      # Users are shared across tenants, so only act on a pending user who belongs to this one
      user = User.for_repository.find(params[:id])
      activated = false
      # The lock makes a second concurrent click see the user as already active
      user.with_lock do
        if user.invited_to_sign_up?
          super
          activated = user.reload.invitation_accepted?
        else
          redirect_to hyrax.admin_users_path, flash: { error: t('hyrax.admin.users.activate.failure', user:) }
        end
      end
      send_activation_instructions(user) if activated
    end

    private

    # Devise's reset-password token and mailer, with a template that does not tell the user to ignore it.
    def send_activation_instructions(user)
      token = user.send(:set_reset_password_token)
      user.send(:send_devise_notification, :reset_password_instructions, token,
                template_name: 'activation_instructions',
                subject: t('hyrax.admin.users.activate.email_subject'))
    end
  end
end

Admin::UsersController.prepend(Admin::UsersControllerDecorator)
