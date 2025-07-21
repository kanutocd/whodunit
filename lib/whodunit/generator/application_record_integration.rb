# frozen_string_literal: true

module Whodunit
  class Generator
    # Handles ApplicationRecord integration functionality
    module ApplicationRecordIntegration
      def self.handle_application_record_integration!
        application_record_file = "app/models/application_record.rb"

        return unless application_record_exists?(application_record_file)

        content = File.read(application_record_file)
        return if stampable_already_included?(content)

        return unless user_wants_application_record_integration?

        add_stampable_to_application_record!(application_record_file, content)
      end

      private_class_method def self.application_record_exists?(file_path)
        return true if File.exist?(file_path)

        puts "⚠️  ApplicationRecord not found at #{file_path}"
        false
      end

      private_class_method def self.stampable_already_included?(content)
        return false unless content.include?("Whodunit::Stampable")

        puts "✅ Whodunit::Stampable already included in ApplicationRecord"
        true
      end

      private_class_method def self.user_wants_application_record_integration?
        puts ""
        puts "🤔 Do you want to include Whodunit::Stampable in ApplicationRecord?"
        puts "   This will automatically enable stamping for ALL your models."
        puts "   (You can always include it manually in specific models instead)"
        print "   Add to ApplicationRecord? (Y/n): "

        response = $stdin.gets.chomp.downcase
        !%w[n no].include?(response)
      end

      private_class_method def self.add_stampable_to_application_record!(file_path, content)
        updated_content = try_primary_pattern(content) || try_fallback_pattern(content)

        if updated_content
          write_updated_application_record!(file_path, updated_content)
        else
          show_manual_integration_message
        end
      end

      private_class_method def self.try_primary_pattern(content)
        return unless content.match?(/^(\s*class ApplicationRecord < ActiveRecord::Base\s*)$/)

        content.gsub(
          /^(\s*class ApplicationRecord < ActiveRecord::Base\s*)$/,
          "\\1\n  include Whodunit::Stampable"
        )
      end

      private_class_method def self.try_fallback_pattern(content)
        return unless content.match?(/^(\s*class ApplicationRecord.*\n)/)

        content.gsub(
          /^(\s*class ApplicationRecord.*\n)/,
          "\\1  include Whodunit::Stampable\n"
        )
      end

      private_class_method def self.write_updated_application_record!(file_path, content)
        File.write(file_path, content)
        puts "✅ Added Whodunit::Stampable to ApplicationRecord"
        puts "   All your models will now automatically include stamping!"
      end

      private_class_method def self.show_manual_integration_message
        puts "⚠️  Could not automatically modify ApplicationRecord"
        puts "   Please manually add: include Whodunit::Stampable"
      end
    end
  end
end
