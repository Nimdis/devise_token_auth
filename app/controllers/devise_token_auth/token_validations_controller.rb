module DeviseTokenAuth
  class TokenValidationsController < DeviseTokenAuth::ApplicationController
    skip_before_action :assert_is_devise_user_resource!, :only => [:validate_token]
    before_action :set_user_by_token, :only => [:validate_token]

    def validate_token
      # @user_resource will have been set by set_user_token concern
      if @user_resource
        yield @user_resource if block_given?
        render_validate_token_success
      else
        render_validate_token_error
      end
    end

    protected

    def render_validate_token_success
      render json: {
        success: true,
        data: user_resource_data(user_resource_json: @user_resource.token_validation_response)
      }
    end

    def render_validate_token_error
      render json: {
        success: false,
        errors: [I18n.t("devise_token_auth.token_validations.invalid")]
      }, status: 401
    end
  end
end
