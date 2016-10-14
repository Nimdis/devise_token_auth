module DeviseTokenAuth
  class ApplicationController < DeviseController
    include DeviseTokenAuth::Concerns::SetUserByToken

    def user_resource_data(opts={})
      response_data = opts[:user_resource_json] || @user_resource.as_json
      if is_json_api
        response_data['type'] = @user_resource.class.name.parameterize
      end
      response_data
    end

    def user_resource_errors
      return @user_resource.errors.to_hash.merge(full_messages: @user_resource.errors.full_messages)
    end

    protected

    def params_for_user_resource(user_resource)
      devise_parameter_sanitizer.instance_values['permitted'][user_resource].each do |type|
        params[type.to_s] ||= request.headers[type.to_s] unless request.headers[type.to_s].nil?
      end
      devise_parameter_sanitizer.instance_values['permitted'][user_resource]
    end

    def user_resource_class(m=nil)
      if m
        mapping = Devise.mappings[m]
      else
        mapping = Devise.mappings[user_resource_name] || Devise.mappings.values.first
      end

      mapping.to
    end

    def is_json_api
      return false unless defined?(ActiveModel::Serializer)
      return ActiveModel::Serializer.setup do |config|
        config.adapter == :json_api
      end if ActiveModel::Serializer.respond_to?(:setup)
      return ActiveModelSerializers.config.adapter == :json_api
    end

  end
end
