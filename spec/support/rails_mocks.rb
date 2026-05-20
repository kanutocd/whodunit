# frozen_string_literal: true

# activesupport and activerecord are runtime dependencies of whodunit and are
# loaded unconditionally by lib/whodunit.rb via `require "active_support/all"`.
# No hand-rolled Rails mocks are needed; this file is intentionally left
# empty so that existing `require` calls in spec files continue to work.
