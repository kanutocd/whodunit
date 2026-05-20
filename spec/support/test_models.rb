# frozen_string_literal: true

require "active_record"
require "logger"

# Connect to an in-memory SQLite3 database
begin
  require "sqlite3"
  ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
rescue LoadError
  # sqlite3 gem not available – use a simple NullDB shim that satisfies the
  # schema creation calls but doesn't persist anything.
  require_relative "null_db_adapter"
end

ActiveRecord::Base.logger = Logger.new(IO::NULL) # silence SQL noise in specs

# Disable schema cache so column_names is always live in tests
ActiveRecord::Base.schema_cache_ignored_tables = [] if ActiveRecord::Base.respond_to?(:schema_cache_ignored_tables=)

# Create schema
ActiveRecord::Schema.define do
  create_table :whodunit_records, force: true do |t|
    t.bigint  :creator_id
    t.bigint  :updater_id
    t.bigint  :deleter_id
    t.timestamps null: false
  end

  create_table :whodunit_soft_delete_records, force: true do |t|
    t.bigint   :creator_id
    t.bigint   :updater_id
    t.bigint   :deleter_id
    t.datetime :deleted_at
    t.timestamps null: false
  end
end

# Real AR model definitions

# Base AR class that keeps Stampable concerns out of ApplicationRecord
class WhodunitTestBase < ActiveRecord::Base
  self.abstract_class = true
end

# Standard model -- mirrors the old MockActiveRecord role
class WhodunitRecord < WhodunitTestBase
  self.table_name = "whodunit_records"
  include Whodunit::Stampable
end

# Soft-delete model -- mirrors the old MockSoftDeleteRecord role
class WhodunitSoftDeleteRecord < WhodunitTestBase
  self.table_name = "whodunit_soft_delete_records"
  include Whodunit::Stampable
end

# Backward-compat aliases
# Many existing specs still reference MockActiveRecord / MockSoftDeleteRecord.
# Alias them so we don't need to rename every example in this PR.

MockActiveRecord       = WhodunitRecord
MockSoftDeleteRecord   = WhodunitSoftDeleteRecord
