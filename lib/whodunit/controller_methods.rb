# frozen_string_literal: true

module Whodunit
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
    def set_whodunit_user(user = nil)
      user ||= current_whodunit_user
      Whodunit::Current.user = user
    end

    def reset_whodunit_user
      Whodunit::Current.reset
    end

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

    def whodunit_user_available?
      current_whodunit_user.present?
    end

    def with_whodunit_user(user)
      previous_user = Whodunit::Current.user
      begin
        Whodunit::Current.user = user
        yield
      ensure
        Whodunit::Current.user = previous_user
      end
    end

    def without_whodunit_user(&block)
      with_whodunit_user(nil, &block)
    end

    class_methods do
      def skip_whodunit_for(*actions)
        return unless respond_to?(:skip_before_action) && respond_to?(:skip_after_action)

        skip_before_action :set_whodunit_user, only: actions
        skip_after_action :reset_whodunit_user, only: actions
      end

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
