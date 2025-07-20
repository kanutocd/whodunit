# frozen_string_literal: true

require "ostruct"

# Mock ActiveRecord::Base for testing
class MockActiveRecord
  # Define class methods before including Stampable
  def self.column_names
    %w[id creator_id updater_id deleter_id created_at updated_at]
  end

  Column = Struct.new(:name, :type)

  def self.columns
    [
      Column.new("id", :integer),
      Column.new("creator_id", :bigint),
      Column.new("updater_id", :bigint),
      Column.new("deleter_id", :bigint),
      Column.new("created_at", :datetime),
      Column.new("updated_at", :datetime)
    ]
  end

  # Define callbacks before including Stampable
  def self.before_create(method, **options)
    # Mock callback registration
  end

  def self.before_update(method, **options)
    # Mock callback registration
  end

  def self.before_destroy(method, **options)
    # Mock callback registration
  end

  def self.skip_callback(*args)
    # Mock callback skipping
  end

  def self.belongs_to(name, **options)
    # Mock belongs_to for testing
  end

  def self.included_modules
    []
  end

  include Whodunit::Stampable

  attr_accessor :creator_id, :updater_id, :deleter_id
  attr_reader :new_record, :attributes

  def initialize(attributes = {})
    @attributes = attributes
    @new_record = true
  end

  def self.respond_to_missing?(_method_name, _include_private = false)
    false
  end

  def new_record?
    @new_record
  end

  def []=(key, value)
    @attributes[key.to_s] = value
  end

  def [](key)
    @attributes[key.to_s]
  end

  def save!
    @new_record = false
    self
  end

  def update!(attrs)
    @new_record = false
    @attributes.merge!(attrs.stringify_keys)
    self
  end

  def destroy!
    # Mock destroy
    self
  end

  def has_attribute?(attr_name)
    self.class.column_names.include?(attr_name.to_s)
  end

  def attribute_changed?(_attr_name)
    # Mock implementation - can be overridden in tests
    false
  end

  def attribute_was(_attr_name)
    # Mock implementation - can be overridden in tests
    nil
  end
end

# Model with soft delete
class MockSoftDeleteRecord < MockActiveRecord
  def self.columns
    super + [Column.new("deleted_at", :datetime)]
  end

  def self.column_names
    super + %w[deleted_at]
  end

  def self.respond_to?(method_name, include_private: false)
    method_name == :deleted_at || super
  end
end
