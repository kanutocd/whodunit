# frozen_string_literal: true

module Whodunit
  # Rails integration for automatic setup of Whodunit functionality.
  #
  # This Railtie automatically extends ActiveRecord migrations with MigrationHelpers
  # and includes ControllerMethods in ActionController::Base when Rails is available.
  # It provides seamless integration without requiring manual setup.
  #
  # @example Automatic integration (no setup required)
  #   # In a Rails app, this automatically provides:
  #   # - Migration helpers (add_whodunit_stamps, etc.)
  #   # - Controller methods (set_whodunit_user, etc.)
  #
  # @note When Rails is not available, this class safely inherits from Object
  #   and does not cause any errors.
  #
  # @since 0.1.0
  class Railtie < (defined?(Rails::Railtie) ? Rails::Railtie : Object)
    if defined?(Rails::Railtie)
      railtie_name :whodunit

      # Extend ActiveRecord with migration helpers.
      #
      # This initializer adds the MigrationHelpers module to ActiveRecord,
      # making methods like add_whodunit_stamps available in migrations.
      #
      # @api private
      initializer "whodunit.extend_active_record" do |_app|
        ActiveSupport.on_load(:active_record) do
          extend Whodunit::MigrationHelpers
        end
      end

      # Include controller methods in ActionController::Base.
      #
      # This initializer adds the ControllerMethods module to ActionController::Base,
      # making methods like set_whodunit_user and current_whodunit_user available
      # in all controllers.
      #
      # @api private
      initializer "whodunit.extend_action_controller" do |_app|
        ActiveSupport.on_load(:action_controller_base) do
          include Whodunit::ControllerMethods
        end
      end
    end
  end
end
