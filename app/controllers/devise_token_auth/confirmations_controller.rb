module DeviseTokenAuth
  class ConfirmationsController < DeviseTokenAuth::ApplicationController
    def show
      @user_resource = user_resource_class.confirm_by_token(params[:confirmation_token])

      if @user_resource and @user_resource.id
        # create client id
        client_id  = SecureRandom.urlsafe_base64(nil, false)
        token      = SecureRandom.urlsafe_base64(nil, false)
        token_hash = BCrypt::Password.create(token)
        expiry     = (Time.now + DeviseTokenAuth.token_lifespan).to_i

        @user_resource.tokens[client_id] = {
          token:  token_hash,
          expiry: expiry
        }

        @user_resource.save!

        yield @user_resource if block_given?

        redirect_to(@user_resource.build_auth_url(params[:redirect_url], {
          token:                        token,
          client_id:                    client_id,
          account_confirmation_success: true,
          config:                       params[:config]
        }))
      else
        raise ActionController::RoutingError.new('Not Found')
      end
    end
  end
end
