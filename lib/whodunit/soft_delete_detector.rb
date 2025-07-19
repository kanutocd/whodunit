# frozen_string_literal: true

module Whodunit
  class SoftDeleteDetector
    def self.enabled_for?(model)
      return false unless model.respond_to?(:columns)

      gem_based_detection(model) ||
        column_pattern_detection(model) ||
        method_based_detection(model)
    end

    def self.gem_based_detection(model)
      # Discard gem
      return true if model.included_modules.any? { |mod| mod.to_s.include?("Discard") }

      # Paranoia gem
      return true if model.respond_to?(:paranoid?) ||
                     model.respond_to?(:acts_as_paranoid) ||
                     model.ancestors.any? { |a| a.to_s.include?("Paranoid") }

      # ActsAsParanoid (older version)
      return true if model.respond_to?(:acts_as_paranoid)

      false
    end

    def self.column_pattern_detection(model)
      soft_delete_columns = %w[
        deleted_at destroyed_at discarded_at archived_at
        soft_deleted_at soft_destroyed_at removed_at
      ]

      model.columns.any? do |column|
        soft_delete_columns.include?(column.name) &&
          timestamp_column?(column)
      end
    end

    def self.method_based_detection(model)
      soft_delete_methods = %w[
        deleted_at destroyed_at discarded_at archived_at
        soft_deleted_at soft_destroyed_at removed_at
      ]

      soft_delete_methods.any? { |method| model.respond_to?(method) }
    end

    def self.timestamp_column?(column)
      %i[datetime timestamp date].include?(column.type)
    end
  end
end
