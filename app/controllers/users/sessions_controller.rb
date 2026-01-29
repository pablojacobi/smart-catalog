# frozen_string_literal: true

module Users
  class SessionsController < Devise::SessionsController
    # GET /users/sign_in
    # def new
    #   super
    # end

    # POST /users/sign_in
    # def create
    #   super
    # end

    # DELETE /users/sign_out
    # def destroy
    #   super
    # end

    protected

    # Redirect to chat after successful sign in
    def after_sign_in_path_for(_resource)
      chat_path
    end

    # Redirect to home after sign out
    def after_sign_out_path_for(_resource_or_scope)
      root_path
    end
  end
end
