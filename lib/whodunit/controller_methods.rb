# frozen_string_literal: true

module Whodunit
  # Controller integration for automatic user setting.
  #
  # This module provides seamless integration with Rails controllers by automatically
  # setting and resetting the current user context for auditing purposes. It includes
  # methods for manual user management and supports various user detection patterns.
  #
  # @example Automatic integration (via Railtie)
  #   # This module is automatically included in ActionController::Base
  #   class PostsController < ApplicationController
  #     # Whodunit automatically tracks current_user for all actions
  #     def create
  #       @post = Post.create(params[:post])
  #       # @post.creator_id is automatically set to current_user.id
  #     end
  #   end
  #
  # @example Manual user setting
  #   class PostsController < ApplicationController
  #     def admin_action
  #       with_whodunit_user(User.admin) do
  #         # Actions here will be tracked as performed by admin user
  #         Post.create(title: "Admin Post")
  #       end
  #     end
  #   end
  #
  # @example Skipping whodunit for specific actions
  #   class PostsController < ApplicationController
  #     skip_whodunit_for :index, :show
  #     # or
  #     whodunit_only_for :create, :update, :destroy
  #   end
  #
  # @since 0.1.0
  module ControllerMethods
    extend ActiveSupport::Concern

    included do
      # Set up callbacks only for controllers that have user authentication
      # Only if Rails controller methods are available
      if respond_to?(:before_action) && respond_to?(:after_action)
        before_action :set_whodunit_user, if: :whodunit_user_available?
        after_action :reset_whodunit_user
      end
    end

    # Set the current user for whodunit tracking.
    #
    # This method is automatically called as a before_action in controllers.
    # Can also be called manually to set a specific user context.
    #
    # @param user [Object, nil] the user object or user ID to set
    #   If nil, attempts to detect user via current_whodunit_user
    # @return [void]
    # @example Manual usage
    #   set_whodunit_user(User.find(123))
    #   set_whodunit_user(nil)  # Uses current_whodunit_user detection
    def set_whodunit_user(user = nil)
      user ||= current_whodunit_user
      Whodunit::Current.user = user
    end

    # Reset the current user context.
    #
    # This method is automatically called as an after_action in controllers
    # to ensure proper cleanup between requests.
    #
    # @return [void]
    def reset_whodunit_user
      Whodunit::Current.reset
    end

    # Detect the current user for auditing.
    #
    # This method tries multiple strategies to find the current user:
    # 1. current_user method (most common Rails pattern)
    # 2. @current_user instance variable
    # 3. Other common authentication method names
    #
    # Override this method in your controller to customize user detection.
    #
    # @return [Object, nil] the current user object or nil if none found
    # @example Custom user detection
    #   def current_whodunit_user
    #     # Custom logic for finding user
    #     session[:admin_user] || super
    #   end
    def current_whodunit_user
      return current_user if respond_to?(:current_user) && current_user
      return @current_user if defined?(@current_user) && @current_user

      # Try other common patterns
      user_methods = %i[
        current_user current_account current_admin
        signed_in_user authenticated_user
      ]

      user_methods.each do |method|
        return send(method) if respond_to?(method, true) && send(method)
      end

      nil
    end

    # Check if a user is available for stamping.
    #
    # Used internally by callbacks to determine if user tracking should occur.
    #
    # @return [Boolean] true if a user is available
    def whodunit_user_available?
      current_whodunit_user.present?
    end

    # Temporarily set a different user for a block of code.
    #
    # Useful for admin actions or background jobs that need to run
    # as a specific user. Automatically restores the previous user context.
    #
    # @param user [Object] the user object to set temporarily
    # @yield the block to execute with the temporary user
    # @return [Object] the return value of the block
    # @example
    #   with_whodunit_user(admin_user) do
    #     Post.create(title: "Admin post")
    #   end
    def with_whodunit_user(user)
      previous_user = Whodunit::Current.user
      begin
        Whodunit::Current.user = user
        yield
      ensure
        Whodunit::Current.user = previous_user
      end
    end

    # Temporarily disable user tracking for a block of code.
    #
    # Useful for system operations or bulk imports where user tracking
    # is not desired.
    #
    # @yield the block to execute without user tracking
    # @return [Object] the return value of the block
    # @example
    #   without_whodunit_user do
    #     Post.bulk_import(data)  # No creator_id will be set
    #   end
    def without_whodunit_user(&)
      with_whodunit_user(nil, &)
    end

    class_methods do
      # Skip whodunit tracking for specific controller actions.
      #
      # Disables automatic user tracking for the specified actions.
      # Useful for read-only actions where auditing is not needed.
      #
      # @param actions [Array<Symbol>] the action names to skip
      # @return [void]
      # @example
      #   class PostsController < ApplicationController
      #     skip_whodunit_for :index, :show
      #   end
      def skip_whodunit_for(*actions)
        return unless respond_to?(:skip_before_action) && respond_to?(:skip_after_action)

        skip_before_action :set_whodunit_user, only: actions
        skip_after_action :reset_whodunit_user, only: actions
      end

      # Enable whodunit tracking only for specific controller actions.
      #
      # Disables automatic tracking for all actions, then re-enables it
      # only for the specified actions. Useful for controllers where
      # only certain actions need auditing.
      #
      # @param actions [Array<Symbol>] the action names to enable tracking for
      # @return [void]
      # @example
      #   class PostsController < ApplicationController
      #     whodunit_only_for :create, :update, :destroy
      #   end
      def whodunit_only_for(*actions)
        return unless respond_to?(:skip_before_action) && respond_to?(:before_action) && respond_to?(:after_action)

        skip_before_action :set_whodunit_user
        skip_after_action :reset_whodunit_user

        before_action :set_whodunit_user, only: actions, if: :whodunit_user_available?
        after_action :reset_whodunit_user, only: actions
      end
    end
  end
end
