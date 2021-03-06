module DeviseTokenAuth
  class RegistrationsController < DeviseTokenAuth::ApplicationController
    before_action :set_user_by_token, :only => [:destroy, :update]
    before_action :validate_sign_up_params, :only => :create
    before_action :validate_account_update_params, :only => :update
    skip_after_action :update_auth_header, :only => [:create, :destroy]

    def create
      @user_resource            = user_resource_class.new(sign_up_params)
      @user_resource.provider   = "email"

      # honor devise configuration for case_insensitive_keys
      if user_resource_class.case_insensitive_keys.include?(:email)
        @user_resource.email = sign_up_params[:email].try :downcase
      else
        @user_resource.email = sign_up_params[:email]
      end

      # give redirect value from params priority
      @redirect_url = params[:confirm_success_url]

      # fall back to default value if provided
      @redirect_url ||= DeviseTokenAuth.default_confirm_success_url

      # success redirect url is required
      if user_resource_class.devise_modules.include?(:confirmable) && !@redirect_url
        return render_create_error_missing_confirm_success_url
      end

      # if whitelist is set, validate redirect_url against whitelist
      if DeviseTokenAuth.redirect_whitelist
        unless DeviseTokenAuth::Url.whitelisted?(@redirect_url)
          return render_create_error_redirect_url_not_allowed
        end
      end

      begin
        # override email confirmation, must be sent manually from ctrl
        user_resource_class.set_callback("create", :after, :send_on_create_confirmation_instructions)
        user_resource_class.skip_callback("create", :after, :send_on_create_confirmation_instructions)
        if @user_resource.save
          yield @user_resource if block_given?

          unless @user_resource.confirmed?
            # user will require email authentication
            @user_resource.send_confirmation_instructions({
              client_config: params[:config_name],
              redirect_url: @redirect_url
            })

          else
            # email auth has been bypassed, authenticate user
            @client_id = SecureRandom.urlsafe_base64(nil, false)
            @token     = SecureRandom.urlsafe_base64(nil, false)

            @user_resource.tokens[@client_id] = {
              token: BCrypt::Password.create(@token),
              expiry: (Time.now + DeviseTokenAuth.token_lifespan).to_i
            }

            @user_resource.save!

            update_auth_header
          end
          render_create_success
        else
          clean_up_passwords @user_resource
          render_create_error
        end
      rescue ActiveRecord::RecordNotUnique
        clean_up_passwords @user_resource
        render_create_error_email_already_exists
      end
    end

    def update
      if @user_resource
        if @user_resource.send(user_resource_update_method, account_update_params)
          yield @user_resource if block_given?
          render_update_success
        else
          render_update_error
        end
      else
        render_update_error_user_not_found
      end
    end

    def destroy
      if @user_resource
        @user_resource.destroy
        yield @user_resource if block_given?

        render_destroy_success
      else
        render_destroy_error
      end
    end

    def sign_up_params
      params.permit(*params_for_user_resource(:sign_up))
    end

    def account_update_params
      params.permit(*params_for_user_resource(:account_update))
    end

    protected

    def render_create_error_missing_confirm_success_url
      render json: {
        status: 'error',
        data:   user_resource_data,
        errors: [I18n.t("devise_token_auth.registrations.missing_confirm_success_url")]
      }, status: 422
    end

    def render_create_error_redirect_url_not_allowed
      render json: {
        status: 'error',
        data:   user_resource_data,
        errors: [I18n.t("devise_token_auth.registrations.redirect_url_not_allowed", redirect_url: @redirect_url)]
      }, status: 422
    end

    def render_create_success
      render json: {
        status: 'success',
        data:   user_resource_data
      }
    end

    def render_create_error
      render json: {
        status: 'error',
        data:   user_resource_data,
        errors: user_resource_errors
      }, status: 422
    end

    def render_create_error_email_already_exists
      render json: {
        status: 'error',
        data:   user_resource_data,
        errors: [I18n.t("devise_token_auth.registrations.email_already_exists", email: @user_resource.email)]
      }, status: 422
    end

    def render_update_success
      render json: {
        status: 'success',
        data:   user_resource_data
      }
    end

    def render_update_error
      render json: {
        status: 'error',
        errors: user_resource_errors
      }, status: 422
    end

    def render_update_error_user_not_found
      render json: {
        status: 'error',
        errors: [I18n.t("devise_token_auth.registrations.user_not_found")]
      }, status: 404
    end

    def render_destroy_success
      render json: {
        status: 'success',
        message: I18n.t("devise_token_auth.registrations.account_with_uid_destroyed", uid: @user_resource.uid)
      }
    end

    def render_destroy_error
      render json: {
        status: 'error',
        errors: [I18n.t("devise_token_auth.registrations.account_to_destroy_not_found")]
      }, status: 404
    end

    private

    def user_resource_update_method
      if DeviseTokenAuth.check_current_password_before_update == :attributes
        "update_with_password"
      elsif DeviseTokenAuth.check_current_password_before_update == :password and account_update_params.has_key?(:password)
        "update_with_password"
      elsif account_update_params.has_key?(:current_password)
        "update_with_password"
      else
        "update_attributes"
      end
    end

    def validate_sign_up_params
      validate_post_data sign_up_params, I18n.t("errors.messages.validate_sign_up_params")
    end

    def validate_account_update_params
      validate_post_data account_update_params, I18n.t("errors.messages.validate_account_update_params")
    end

    def validate_post_data which, message
      render json: {
         status: 'error',
         errors: [message]
      }, status: :unprocessable_entity if which.empty?
    end
  end
end
