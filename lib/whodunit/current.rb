# frozen_string_literal: true

module Whodunit
  # Thread-safe current user context using Rails CurrentAttributes.
  #
  # This class provides a thread-safe way to store the current user for auditing purposes.
  # It leverages Rails' CurrentAttributes functionality to ensure proper isolation
  # across threads and requests.
  #
  # @example Setting a user
  #   Whodunit::Current.user = User.find(123)
  #   Whodunit::Current.user = 123  # Can also set by ID directly
  #
  # @example Getting the user ID
  #   Whodunit::Current.user_id  # => 123
  #
  # @example In a controller
  #   class ApplicationController < ActionController::Base
  #     before_action :set_current_user
  #
  #     private
  #
  #     def set_current_user
  #       Whodunit::Current.user = current_user
  #     end
  #   end
  #
  # @since 0.1.0
  class Current < ActiveSupport::CurrentAttributes
    # @!attribute [rw] user
    #   @return [Integer, nil] the current user ID
    attribute :user

    # Set the current user by object or ID.
    #
    # Accepts either a user object (responds to #id) or a user ID directly.
    # The user ID is stored for database operations.
    #
    # @param user [Object, Integer, nil] user object or user ID
    # @return [Integer, nil] the stored user ID
    # @example
    #   Whodunit::Current.user = User.find(123)
    #   Whodunit::Current.user = 123
    #   Whodunit::Current.user = nil  # Clear current user
    def self.user=(user)
      super(user.respond_to?(:id) ? user.id : user)
    end

    # Get the current user ID for database storage.
    #
    # @return [Integer, nil] the current user ID
    # @example
    #   Whodunit::Current.user = User.find(123)
    #   Whodunit::Current.user_id  # => 123
    def self.user_id
      user
    end
  end
end
