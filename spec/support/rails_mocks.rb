# frozen_string_literal: true

# Mock Rails classes for testing when Rails isn't loaded
unless defined?(Rails)
  module Rails
    class Railtie
      def self.railtie_name(name = nil)
        @railtie_name = name if name
        @railtie_name
      end

      def self.initializer(name, **options, &block)
        @initializers ||= []
        @initializers << { name: name, options: options, block: block }
      end

      def self.initializers
        @initializers || []
      end
    end
  end

  module ActiveSupport
    def self.on_load(component, &block)
      # Mock - in real Rails this would call the block when the component is loaded
    end
  end
end
