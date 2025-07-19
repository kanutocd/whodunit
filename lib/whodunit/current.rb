# frozen_string_literal: true

module Whodunit
  class Current < ActiveSupport::CurrentAttributes
    attribute :user

    def self.user=(user)
      super(user.respond_to?(:id) ? user.id : user)
    end

    def self.user_id
      user
    end
  end
end
